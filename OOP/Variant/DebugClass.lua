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

local setmetatable = setmetatable;
local rawset = rawset;
local pairs = pairs;
local ipairs = ipairs;
local assert = assert;
local type = type;

local Config = require("OOP.Config");
local E_Handlers = require("OOP.Event").Handlers;
local R = require("OOP.Router")
local Permission = R.Permission;
local Compat = require("OOP.Version.Compat");
local bits = Compat.bits;
local FunctionWrapper = Compat.FunctionWrapper;

local __r__ = Config.__r__;
local __w__ = Config.__w__;
local __bases__ = Config.__bases__;
local __all__ = Config.__all__;
local __pm__ = Config.__pm__;
local __cls__ = Config.__cls__;
local __members__ = Config.__members__;
local __meta__ = Config.__meta__;

local Handlers = Config.Handlers;
local On = Config.On;
local AllowClassName = Config.AllowClassName;
local AllowInheriteTable = Config.AllowInheriteTable;
local Instance = Config.Instance;

local new = Config.new;
local delete = Config.delete;
local is = Config.is;
local __init__ = Config.__init__;
local __del__ = Config.__del__;

local IsCppClass = Config.CppClass.IsCppClass;

local BaseClass = require("OOP.Variant.BaseClass");
local class = BaseClass.class;
local AllClasses = BaseClass.AllClasses;
local ClassIs = BaseClass.ClassIs;
local AccessStack = BaseClass.AccessStack;
local Copy = BaseClass.Copy;

local DebugFunctions = require("OOP.Variant.DebugFunctions");
local MakeLuaObjMetaTable = DebugFunctions.MakeLuaObjMetaTable;
local RetrofitMeta = DebugFunctions.RetrofitMeta;
local ClassGet = DebugFunctions.ClassGet;
local ClassSet = DebugFunctions.ClassSet;
local DefaultDelete = DebugFunctions.DefaultDelete;
class.__DefaultDelete = DefaultDelete;

local ClassCreateLayer = 0;
function class.New(...)
    local cls = {
        -- All event handlers.
        [Handlers] = {},
        [__bases__] = {},
        [__members__] = {},

        [__all__] = {},
        [__pm__] = {},
        [__meta__] = {},

        -- Represents the c++ base class of the class (and also the only c++ base class).
        __cpp_base__ = nil,

        -- function constructor in the index of the inheritance list, once the type has been constructed once,
        -- this field will be invalidated.
        __fCtorIdx__ = nil
    };

    local bases = cls[__bases__];
    local members = cls[__members__];
    local metas = cls[__meta__];
    local handlers = cls[Handlers];

    setmetatable(handlers,{
        __newindex = function(t,key,value)
            assert(
                "string" == type(key) and key:find(On) == 1,
                ("The name of handler function must start with \"%s\"."):format(On)
            );
            assert("function" == type(value),"Event handler must be a function.");
            -- Ensure that event response functions have access to member variables.
            rawset(t,key,FunctionWrapper(AccessStack,cls,value));
        end
    });

    -- register meta-table of properties for class.
    for _,rw in pairs({__r__,__w__}) do
        cls[rw] = setmetatable({},{
            __index = function (_,key)
                for _,base in ipairs(bases) do
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
            AllClasses[cls] = name;
        else
            -- Duplicative class name.
            error(("You cannot use this name \"%s\", which is already used by other class.").format(name));
        end
    end

    for idx, base in ipairs(args) do
        local baseType = type(base);
        assert(
            (baseType == "table" or baseType == "function")
            or (AllowClassName and baseType == "string"),
            "Unavailable base class type."
        );
        if AllowClassName and "string" == baseType then
            assert(AllClasses[base],("Inherits a class that does not exist.[\"%s\"]").format(base));
            -- Find the base.
            base = AllClasses[base];
        elseif baseType == "function" then
            -- One __create__ function only.
            assert(cls.__create__ == nil,"Class with more than one creating function.");
            cls.__create__ = base;
            -- __fCtorIdx__ indicates where the function constructor is located,
            -- and adds the class to this when first constructed.
            cls.__fCtorIdx__ = idx;
        else
            local constructor = IsCppClass and IsCppClass(base);
            if constructor then
                -- It is a c++ class.
                assert(cls.__create__ == nil,"Class with more than one creating function or native class.");
                local bCtor = base[constructor];
                if bCtor then
                    cls.__create__ = bCtor;
                end
                cls.__cpp_base__ = base;
            else
                if nil == rawget(base,__bases__) then
                    -- Inherite a simple table?
                    if AllowInheriteTable then
                        base[__r__] = {};
                        base[__w__] = {};
                        base[__bases__] = {};
                        base[Handlers] = {};
                    else
                        error("Inheriting a table is not supported.");
                    end
                end
                local __create__ = rawget(base,"__create__");
                if __create__ then
                    assert(cls.__create__ == nil,"Class with more than one creating function.");
                    -- When having the value __fCtorIdx__,
                    -- which indicates that the base class uses the function constructor
                    -- Assign cls.__create to base.new to be called recursively
                    -- in order to return the class to which the function constructor produces the object.
                    cls.__create__ = rawget(base,"__fCtorIdx__") and base[new] or __create__;
                end

                for hdr,func in pairs(base[Handlers]) do
                    -- Inherite handlers from base.
                    handlers[hdr] = func;
                end
                for key,mem in pairs(base[__members__]) do
                    -- Inherite members from base.
                    members[key] = mem;
                end
                for key,meta in pairs(base[__meta__]) do
                    -- Inherite metas from base.
                    metas[key] = meta;
                end
                table.insert(bases,base);
            end
        end
    end

    local _is = function (...)
        return ClassIs(cls,bases,...);
    end;
    cls[is] = _is;

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
                obj = {[__all__] = {}};
            end

            if nil == obj then
                ClassCreateLayer = ClassCreateLayer - 1;
                return nil;
            end

            local instType = type(obj);
            if ClassCreateLayer == 1 then
                local all = "table" == instType and obj[__all__] or obj;
                for key,mem in pairs(members) do
                    -- Automatically set member of object.
                    -- Before the instance can change the meta-table, its members must be set.
                    all[key] = Copy(mem);
                end

                if "table" == instType then
                    -- Instances of the table type do not require the last cls information
                    -- (which is already included in the metatable and in the upvalue).
                    obj[__cls__] = nil;
                    setmetatable(obj,MakeLuaObjMetaTable(cls));

                    -- If the object is a table,
                    -- provide a delete method to the object by default.

                    -- If the object is a userdata,
                    -- you should provide a delete method with c++.

                    -- Since you cannot explicitly determine the return type of the function constructor,
                    -- register the delete function when you know explicitly that it is not returning userdata after constructing it once.
                    if nil == rawget(cls[__all__],delete) then
                        cls[__all__][delete] = FunctionWrapper(AccessStack,cls,DefaultDelete);
                        local pm = cls[__pm__][__del__] or Permission.Public;
                        if cls[__r__][Instance] and bits.band(pm,Permission.Private) == 0 then
                            -- If there is a singleton, at least the protected permission for delete will be guaranteed.
                            cls[__pm__][delete] = Permission.Protected;
                        else
                            -- Otherwise delete has the same access premission as __del__.
                            cls[__pm__][delete] = pm;
                        end
                    end
                else
                    -- Instances of the userdata type require the last cls information.
                    -- Because multiple different lua classes can inherit from the same c++ class.
                    local uv,_ = debug.getuservalue(obj);
                    if not uv then
                        uv = {};
                        debug.setuservalue(obj,uv);
                    end
                    uv[__cls__] = cls;
                    uv[is] = _is;
                    RetrofitMeta(obj);
                end
                for key,func in pairs(handlers) do
                    -- Automatically listens to events.
                    E_Handlers.On(key:sub(3),obj,func);
                end
            else
                if "table" == instType then
                    -- Returning cls together can indicate the class to which the function constructor belongs.
                    obj[__cls__] = cls;
                end
            end

            local init = cls[__init__];
            -- Do not get __init__ from __all__ and make it search automatically.
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
        -- In debug mode,the "new" method is public and static.
        cls[__all__][new] = FunctionWrapper(AccessStack,cls,_new);
        -- Use + instead of | to try to keep lua 5.3 or lower compatible.
        cls[__pm__][new] = Permission.Public + Permission.Static;
    end

    setmetatable(cls,{
        __index = ClassGet,
        __newindex = ClassSet
    });

    return cls;
end