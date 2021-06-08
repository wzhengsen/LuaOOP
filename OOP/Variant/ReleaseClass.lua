-- Copyright (c) 2021 榆柳松

-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:

-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.

local getmetatable = getmetatable;
local setmetatable = setmetatable;
local rawset = rawset;
local pairs = pairs;
local ipairs = ipairs;
local type = type;

local Config = require("OOP.Config");
local Handler = require("OOP.Handler");

local __r__ = Config.__r__;
local __w__ = Config.__w__;
local __bases__ = Config.__bases__;

local Handlers = Config.Handlers;
local AllowClassName = Config.AllowClassName;
local AllowInheriteTable = Config.AllowInheriteTable;

local new = Config.new;
local delete = Config.delete;
local is = Config.is;
local __init__ = Config.__init__;

local IsCppClass = Config.CppClass.IsCppClass;
local IsInherite = Config.CppClass.IsInherite;

local BaseClass = require("OOP.Variant.BaseClass");
local class = BaseClass.class
local DefaultDelete = BaseClass.DefaultDelete;
local AllClasses = BaseClass.AllClasses;

local ReleaseFunctions = require("OOP.Variant.ReleaseFunctions");
local MakeLuaObjMetaTable = ReleaseFunctions.MakeLuaObjMetaTable;
local RetrofitMeta = ReleaseFunctions.RetrofitMeta;
local ClassGet = ReleaseFunctions.ClassGet;
local ClassSet = ReleaseFunctions.ClassSet;

local ClassCreateLayer = 0;
function class.New(...)
    local cls = {
        -- All event handlers.
        [Handlers] = {},
        [__bases__] = {},

        -- Represents the c++ base class of the class (and also the only c++ base class).
        __cpp_base__ = nil,

        -- function constructor in the index of the inheritance list, once the type has been constructed once,
        -- this field will be invalidated.
        __fCtorIdx__ = nil
    };

    local bases = cls[__bases__];
    local handlers = cls[Handlers];

    -- register meta-table of properties for class.
    for _,rw in pairs({__r__,__w__}) do
        cls[rw] = setmetatable({},{
            __index = function (_,key)
                for __,base in ipairs(bases) do
                    local ret = base[rw][key];
                    if nil ~= ret then
                        return ret;
                    end
                end
            end
        });
    end

    local args = {...};
    if AllowClassName and type(args[1]) == "string" then
        -- Check the class name.
        local name = table.remove(args,1);
        if nil == AllClasses[name] then
            AllClasses[name] = cls;
        end
    end

    for idx, base in ipairs(args) do
        local baseType = type(base);
        if AllowClassName and "string" == baseType then
            -- Find the base.
            base = AllClasses[base];
        elseif baseType == "function" then
            cls.__create__ = base;
            -- __fCtorIdx__ indicates where the function constructor is located,
            -- and adds the class to this when first constructed.
            cls.__fCtorIdx__ = idx;
        else
            local constructor = IsCppClass and IsCppClass(base);
            if constructor then
                -- It is a c++ class.
                local bCtor = base[constructor];
                if bCtor then
                    cls.__create__ = bCtor;
                end
                cls.__cpp_base__ = base;
            else
                if AllowInheriteTable and nil == getmetatable(base) then
                    -- Inherite a simple table?
                    base[__r__] = {};
                    base[__w__] = {};
                    base[__bases__] = {};
                    base[Handlers] = {};
                end
                local __create__ = rawget(base,"__create__");
                if __create__ then
                    -- When having the value __fCtorIdx__,
                    -- which indicates that the base class uses the function constructor
                    -- Assign cls.__create to base.new to be called recursively
                    -- in order to return the class to which the function constructor produces the object.
                    cls.__create__ = rawget(base,"__fCtorIdx__") and base[new] or __create__;
                end

                for hdr,func in pairs(base[Handlers]) do
                    -- Inherite handlers from bases.
                    handlers[hdr] = func;
                end
                table.insert(bases,base);
            end
        end
    end

    ---@param baseCls? any  If there is no baseCls parameter,it means the return value is the current type.
    ---@return boolean | table
    local _is = function(baseCls)
        if nil == baseCls then
            return cls;
        end
        if baseCls == cls then
            return true;
        end
        for _,base in ipairs(bases) do
            local _is = base[is];
            if _is then
                if _is(baseCls) then
                    return true;
                end
            elseif IsInherite and IsInherite(base,baseCls) then
                return true;
            end
        end
        return false;
    end;
    cls[is] = _is;

    local meta = MakeLuaObjMetaTable(cls);
    local __create__ = cls.__create__;
    if not cls.__cpp_base__ or __create__ then
        -- If a c++ class does not have a registered constructor,
        -- then the class cannot be instantiated.
        local _new = function(...)
            ClassCreateLayer = ClassCreateLayer + 1;
            --[[
                Here, the case of multiple function constructions needs to be considered, e.g.

                local C1 = class();
                local C2 = class(function()return C1.new();end);
                local C3 = class(C2);
                local C4 = class(function()return C3.new();end);

                In this inheritance relationship,
                since the base classes of C4 and C2 are not explicitly specified,
                you cannot directly query by __bases__ field,
                you need to get the returned base class type and add it to __bases__.


                Since a function constructor is designed to return the same type,
                do not use the following inheritance.

                local E1 = class();
                local E2 = class();
                local E3 = class(function(case)
                    if case == 1 then
                        reutrn E1.new();
                    else
                        return E2.new();
                    end
                );
            ]]
            local obj = nil;
            if __create__ then
                obj = __create__(...);
                if obj then
                    local __fCtorIdx__ = rawget(cls,"__fCtorIdx__");
                    if __fCtorIdx__ then
                        local preCls = obj[is]();
                        if preCls then
                            -- After inserting the class to which the function constructor belongs into the multi-inheritance table,
                            -- __fCtorIdx__ can no longer be used.
                            rawset(cls,"__fCtorIdx__",nil);
                            table.insert(cls[__bases__],__fCtorIdx__,preCls);
                        end
                    end
                end
            else
                obj = {};
            end

            if nil == obj then
                ClassCreateLayer = ClassCreateLayer - 1;
                return nil;
            end

            local instType = type(obj);
            if ClassCreateLayer == 1 then
                if "table" == instType then
                    -- Instances of the table type do not require the last cls information
                    -- (which is already included in the metatable and in the upvalue).
                    obj.__cls__ = nil;
                    setmetatable(obj,meta);

                    -- If the object is a table,
                    -- provide a delete method to the object by default.

                    -- If the object is a userdata,
                    -- you should provide a delete method with c++.

                    -- Since you cannot explicitly determine the return type of the function constructor,
                    -- register the delete function when you know explicitly that it is not returning userdata after constructing it once.
                    if nil == rawget(cls,delete) then
                        rawset(cls,delete,DefaultDelete);
                    end
                else
                    -- Instances of the userdata type require the last cls information.
                    -- Because multiple different lua classes can inherit from the same c++ class.
                    local uv,_ = debug.getuservalue(obj);
                    uv.__cls__ = cls;
                    uv[is] = _is;
                    RetrofitMeta(obj);
                end
                for key,func in pairs(handlers) do
                    -- Automatically listens to events.
                    Handler.On(key:sub(3),obj,func);
                end
            else
                if "table" == instType then
                    -- Returning cls together can indicate the class to which the function constructor belongs.
                    obj.__cls__ = cls;
                end
            end

            local init = cls[__init__];
            if init then
                -- Avoid recursively polluting the classCreateLayer variable when create a new object in the ctor.
                -- Cache it, after the call, set it to classCreateLayer+tempCreateLayer
                -- The final call ends with the value -1.
                local tempCreateLayer = ClassCreateLayer;
                ClassCreateLayer = 0;
                init(obj,...);
                ClassCreateLayer = ClassCreateLayer + tempCreateLayer - 1;
            else
                ClassCreateLayer = ClassCreateLayer - 1;
            end
            return obj;
        end;
        cls[new] = _new;
    end

    return setmetatable(cls,{
        __index = ClassGet,
        __newindex = ClassSet
    });
end

return class;