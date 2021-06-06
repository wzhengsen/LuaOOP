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
local assert = assert;
local type = type;

local Config = require("OOP.Config");
local Handler = require("OOP.Handler");
local Debug = Config.Debug or false;
local Version = Config.Version;

local R = require("OOP.Router")
local Router = R.Router;
local BitsMap = R.BitsMap;
local Permission = R.Permission;

local __r__ = Config.__r__;
local __w__ = Config.__w__;
local __bases__ = Config.__bases__;
local __all__ = Config.__all__;
local __pm__ = Config.__pm__;

local Handlers = Config.Handlers;
local Properties = Config.Properties;
local Friends = Config.Friends;
local Singleton = Config.Singleton;
local PropertyBehavior = Config.PropertyBehavior;
local On = Config.On;
local AllowClassName = Config.AllowClassName;
local AllowInheriteTable = Config.AllowInheriteTable;
local Modifiers = Config.Modifiers;

local new = Config.new;
local delete = Config.delete;
local is = Config.is;
local __init__ = Config.__init__;
local __del__ = Config.__del__;
local DeathMarker = Config.DeathMarker;

local Null = Config.CppClass.Null;
local IsCppClass = Config.CppClass.IsCppClass;
local IsInherite = Config.CppClass.IsInherite;

local Meta = Config.Meta;
local MetaDefault = Config.MetaDefault;
local __pairs__ = MetaDefault.__pairs;
local __len__ = MetaDefault.__len;
local __eq__ = MetaDefault.__eq;

local Cache = Config.Cache;

local ClassAccessTable = {};
local class = {};
rawset(_G,Config.class,class);

-- Object's meta-table implementation.
local ObjMeta = {};
for meta, name in pairs(Meta)do
    ObjMeta[meta] = function (self,...)
        local f = self[name];
        if f then
            return meta(self,...);
        end
        -- If you use an operation that is not implemented, an error will be raised.
        error("You must implement the " .. name .. " meta-method.");
    end
end

-- The following meta-methods use a default implementation.
for meta,name in pairs(MetaDefault) do
    if meta == "__gc" or meta == "__close" then
        ObjMeta[meta] = function (self)
            local f = self[name];
            if f then
                f(self);
            end
        end
    end
end
ObjMeta.__eq = function (...)
    for _,sender in {...} do
        local __eq = sender[__eq__];
        if __eq then
            return __eq(...);
        end
    end
    return false;
end
ObjMeta.__pairs = function (self)
    local __pairs = self[__pairs__];
    if __pairs then
        return __pairs(self);
    end
    return function(t,key)
        local value = nil;
        key,value = next(t,key);
        return key,value;
    end,self,nil;
end
ObjMeta.__len = function (self)
    local __len = self[__len__];
    if __len then
        return __len(self);
    end
    return rawlen(self);
end

local function ClassCheckPermission(pm,key)
    local decor = pm[key];
    if decor then

    end
end

---Cascade to get the value of the corresponding key of a class and its base class
---(ignoring metamethods).
---
---@param self table
---@param key any
---@return any
---
local function CascadeGet(self,key)
    local ret = rawget(self,key);
    if nil ~= ret then
        return ret;
    end
    local bases = rawget(self,__bases__);
    if bases then
        for _,base in ipairs(bases) do
            ret = CascadeGet(base,key);
            if nil ~= ret then
                return ret;
            end
        end
    end
end
--[[
    Cascade calls to __del__.
    @param self     The object that will be destructured.
    @param cls      The class to be looked up.
    @param called   Records which base classes have been called,See below:
                 X
                 |
                 A
                / \
               B   C
                \ /
                 D
    When you destruct the D object,
    to avoid repeated calls to the destructors of X and A that have been inherited multiple times,
    record the classes that have been called in "called".
]]
local function CascadeDelete(self,cls,called)
    if called[cls] then
        return;
    end
    local cppCls = IsCppClass and IsCppClass(cls);
    local del = nil;
    if cppCls then
        del = cls[__del__];
    else
        for _,base in ipairs(cls[__bases__]) do
            CascadeDelete(self,base);
        end
        del = rawget(cls,__del__);
    end
    if del then
        del(self);
    end
    called[cls] = true;
end

--[[为纯lua类产生的table类型的对象指定一个元表。
]]
local function DebugMakeLuaObjMetaTable(cls)
    -- local meta = {
    --     __index = function (sender,key)
    --         -- 先检查当前类型的对应键。
    --         local ret = rawget(cls,key);
    --         if nil ~= ret then
    --             return ret;
    --         end
    --         -- 检查属性。
    --         local property = cls.__r__[key];
    --         if property then
    --             return property(sender);
    --         else
    --             if cls.__w__[key] then
    --                 -- 不能读取只写属性。
    --                 warn("You can't read a write-only property.")
    --                 return nil;
    --             end
    --         end
    --         -- 检查基类。
    --         for _, base in ipairs(cls.__bases__) do
    --             ret = CascadeGet(base,key);
    --             if nil ~= ret then
    --                 -- 此处缓存，加快下次访问。
    --                 rawset(sender,key,ret);
    --                 return ret;
    --             end
    --         end
    --     end,
    --     __newindex = function (sender,key,value)
    --         local property = cls.__w__[key];
    --         if property then
    --             property(sender,value);
    --             return;
    --         else
    --             if cls.__r__[key] then
    --                 -- 不能写入只读属性。
    --                 warn("You can't write a read-only property.")
    --                 return;
    --             end
    --         end
    --         rawset(sender,key,value);
    --     end
    -- };
    -- for k,v in pairs(ObjMeta) do
    --     meta[k] = v;
    -- end
    -- return meta;
end

---
---Generate a meta-table for an object (typically a table) generated by a pure lua class.
---
---@param cls table
---@return table
---
local function MakeLuaObjMetaTable(cls)
    local meta = {
        __index = function (sender,key)
            -- Check the key of current class first.
            local ret = rawget(cls,key);
            if nil ~= ret then
                return ret;
            end
            -- Check the properties of current class.
            local property = cls[__r__][key];
            if property then
                return property(sender);
            end
            -- Check base class.
            for _, base in ipairs(cls[__bases__]) do
                ret = CascadeGet(base,key);
                if nil ~= ret then
                    if Cache then
                        rawset(sender,key,ret);
                    end
                    return ret;
                end
            end
        end,
        __newindex = function (sender,key,value)
            local property = cls[__w__][key];
            if property then
                property(sender,value);
                return;
            end
            rawset(sender,key,value);
        end
    };
    for k,v in pairs(ObjMeta) do
        meta[k] = v;
    end
    return meta;
end

---
--- Retrofit userdata's meta-table to fit lua-class's hybrid inheritance pattern.
---
---@param ud userdata
---
local function RetrofitMeta(ud)
    local meta = getmetatable(ud);
    -- It has been Retrofited,skip it.
    if rawget(meta,"__lua_🛠") then
        return;
    end
    local index = rawget(meta,"__index");
    local newIndex = rawget(meta,"__newindex");
    rawset(meta,"__index",function (sender,key)
        local uv = (debug.getuservalue(ud));
        local cls = uv.__cls__;
        -- Check cls methods and members.
        local ret = rawget(cls,key);
        if nil ~= ret then
            return ret;
        end
        -- Check cls properties.
        local property = cls[__r__][key];
        if property then
            return property(sender);
        end
        -- Check cls bases.
        for _, base in ipairs(cls[__bases__]) do
            ret = CascadeGet(base,key);
            if nil ~= ret then
                if Cache then
                    rawset(uv,key,ret);
                end
                return ret;
            end
        end
        -- Finally, check the original method.
        return index(sender,key);
    end);
    rawset(meta,"__newindex",function (sender,key,val)
        local uv = (debug.getuservalue(sender));
        local cls = uv.__cls__;
        local property = cls[__w__][key];
        if property then
            property(sender,val);
            return;
        end
        -- Finally, write by the original method.
        newIndex(sender,key,val);
    end);

    rawset(meta,"__lua_🛠",true);
end

local HandlerMetaTable = {
    __newindex = function(t,key,value)
        assert(
            "string" == type(key) and key:find(On) == 1,
            ("The name of handler function must start with \"%s\"."):format(On)
        );
        assert("function" == type(value),"Event handler must be a function.");
        rawset(t,key,value);
    end
};

local DefaultDelete = function(self)
    CascadeDelete(self,self[is](),{});
    setmetatable(self,nil);
    self[DeathMarker] = true;
end

local rwTable = {[__r__] = "r",[__w__] = "w"};
local function DebugClassGet(self,key)
    if BitsMap[key] then
        return Router:Begin(self,key);
    end
    -- Check the properties first.
    local property = self[__r__][key];
    if property then
        return property(self);
    else
        if self[__w__][key] then
            if PropertyBehavior ~= 2 then
                if Debug then
                    if PropertyBehavior == 0 then
                        if Version > 5.4 then
                            warn("You can't read a write-only property.");
                        end
                    elseif PropertyBehavior == 1 then
                        error("You can't read a write-only property.");
                    end
                end
                return nil;
            end
        end
    end
    for _, base in ipairs(self[__bases__]) do
        local ret = CascadeGet(base,key);
        if nil ~= ret then
            return ret;
        end
    end
    -- If not found, look for the c++ class.
    local __cpp_base__ = rawget(self,"__cpp_base__");
    if __cpp_base__ then
        return __cpp_base__[key];
    end
end
local function DebugClassSet(self,key,value)
    if key == Properties then
        if "function" == type(value) then
            -- If it is a function?
            -- Call it automatically.
            value = value(self);
        end
        -- Register properties.
        for __rw__,rw in pairs(rwTable) do
            local subT = value[rw];
            if subT then
                for k,v in pairs(subT) do
                    self[__rw__][k] = v;
                end
            end
        end
    else
        local property = self[__w__][key];
        if property then
            property(self,value);
            return;
        else
            if self[__r__][key] then
                if PropertyBehavior ~= 2 then
                    if Debug then
                        if PropertyBehavior == 0 then
                            if Version > 5.4 then
                                warn("You can't write a read-only property.");
                            end
                        elseif PropertyBehavior == 1 then
                            error("You can't write a read-only property.");
                        end
                    end
                    return;
                end
            end
        end
        self[__all__][key] = value;
    end
end

---In non-debug mode, no access modifiers are considered.
---
---@param self table
---@param key any
---@return any
---
local function ClassGet(self,key)
    if BitsMap[key] then
        return self;
    end
    -- Check the properties first.
    local property = self[__r__][key];
    if property then
        return property(self);
    end
    for _, base in ipairs(self[__bases__]) do
        local ret = CascadeGet(base,key);
        if nil ~= ret then
            if Cache then
                -- Cache it to speed up the next visit.
                rawset(self,key,ret);
            end
            return ret;
        end
    end
    -- If not found, look for the c++ class.
    local __cpp_base__ = rawget(self,"__cpp_base__");
    if __cpp_base__ then
        return __cpp_base__[key];
    end
end

local function ClassSet(self,key,value)
    if key == Properties then
        -- It must be a function.
        -- Call it automatically.
        value = value(self);
        -- Register properties.
        for __rw__,rw in pairs(rwTable) do
            local sub = value[rw];
            if sub then
                local dst = self[__rw__];
                for k,v in pairs(sub) do
                    dst[k] = v;
                end
            end
        end
    else
        local property = self[__w__][key];
        return property and property(self,value) or rawset(self,key,value);
    end
end


local AllClasses = {};
local ClassCreateLayer = 0;

function class.New(...)
    local cls = {
        -- All event handlers.
        [Handlers] = Debug and setmetatable({},HandlerMetaTable) or {},
        [__bases__] = {},

        [__all__] = Debug and {} or nil,
        [__pm__] = Debug and {} or nil,

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
        elseif Debug then
            -- Duplicative class name.
            error(("You cannot use this name \"%s\", which is already used by other class.").format(name));
        end
    end

    for idx, base in ipairs(args) do
        local baseType = type(base);
        if Debug then
            assert(
                (baseType == "table" or baseType == "function")
                or (AllowClassName and baseType == "string"),
                "Unavailable base class type."
            );
        end
        if AllowClassName and "string" == baseType then
            if Debug then
                assert(AllClasses[base],("Inherits a class that does not exist.[\"%s\"]").format(base));
            end
            -- Find the base.
            base = AllClasses[base];
        elseif baseType == "function" then
            if Debug then
                -- One __create__ function only.
                assert(cls.__create__ == nil,"Class with more than one creating function.");
            end
            cls.__create__ = base;
            -- __fCtorIdx__ indicates where the function constructor is located,
            -- and adds the class to this when first constructed.
            cls.__fCtorIdx__ = idx;
        else
            local constructor = IsCppClass and IsCppClass(base);
            if constructor then
                -- It is a c++ class.
                if Debug then
                    assert(cls.__create__ == nil,"Class with more than one creating function or native class.");
                end
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
                    if Debug then
                        assert(cls.__create__ == nil,"Class with more than one creating function.");
                    end
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

    setmetatable(cls,{
        __index = Debug and DebugClassGet or ClassGet,
        __newindex = Debug and DebugClassSet or ClassSet
    });

    local __cpp_base__
    if rawget(cls,"__cpp_base__") then
        -- If the object is a table,
        -- provide a delete method to the object by default.

        -- If the object is a userdata,
        -- you should provide a delete method with c++.
        cls[delete] = DefaultDelete;
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
            if base[is](baseCls) then
                return true;
            end
        end
        if IsInherite then
            local cppBase = cls.__cpp_base__;
            if cppBase then
                return IsInherite(cppBase,baseCls);
            end
        end
        return false;
    end;
    cls[is] = _is;

    local meta = Debug and DebugMakeLuaObjMetaTable(cls) or MakeLuaObjMetaTable(cls);
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
        if Debug then
            -- In debug mode,the "new" method is public and static.
            cls[__all__][new] = _new;
            -- 使用+而不使用|以尽量保持lua5.3以下的兼容。
            cls[__pm__][new] = Permission.Public | Permission.Static;
        else
            cls[new] = _new;
        end
    end



    -- -- 处理单例继承。
    -- if singleton then
    --     -- 使用单例，new被禁止。
    --     local new = cls.new;
    --     cls.new = nil;
    --     cls.__properties__ = {
    --         r = {
    --             Instance = function (self)
    --                 if class.IsNull(self.__SingletonInst) then
    --                     self.__SingletonInst = new();
    --                 end
    --                 return self.__SingletonInst;
    --             end
    --         },
    --         w = {
    --             Instance = function (self,val)
    --                 -- 单例销毁时必须使用nil值。
    --                 assert(nil == val,"The nil value must be used to destroy the singleton.")
    --                 if not class.IsNull(self.__SingletonInst) then
    --                     self.__SingletonInst:delete()
    --                     self.__SingletonInst = nil;
    --                 end
    --             end
    --         }
    --     };
    -- end

    return cls;
end

class.IsNull = Null and function(t)
    local tt = type(t);
    if tt == "table" then
        return rawget(t,DeathMarker);
    elseif tt == "userdata" then
        return Null(t);
    end
    return t;
end or
function(t)
    if type(t) == "table" then
        return rawget(t,DeathMarker);
    end
    return t;
end;
class.__DefaultDelete = DefaultDelete;

setmetatable(class,{
    __metatable = "Can't visit the metatable.",
    __call = function(c,...)
        return c.New(...)
    end
});