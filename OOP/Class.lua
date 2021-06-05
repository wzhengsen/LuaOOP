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

local Handlers = Config.Handlers;
local Properties = Config.Properties;
local Friendly = Config.Friendly;
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

--[[
    级联获取某个类及其基类的对应键的值（忽略元方法）。
]]

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
    for _,base in pairs(self.__bases__) do
        ret = CascadeGet(base,key);
        if nil ~= ret then
            return ret;
        end
    end
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

--[[为纯lua类产生的table类型的对象指定一个元表。
]]
local function MakeLuaObjMetaTable(cls)
    local meta = {
        __index = function (sender,key)
            -- 先检查当前类型的对应键。
            local ret = rawget(cls,key);
            if nil ~= ret then
                return ret;
            end
            -- 检查属性。
            local property = cls.__r__[key];
            if property then
                return property(sender);
            else
                if cls.__w__[key] then
                    -- 不能读取只写属性。
                    warn("You can't read a write-only property.")
                    return nil;
                end
            end
            -- 检查基类。
            for _, base in ipairs(cls.__bases__) do
                ret = CascadeGet(base,key);
                if nil ~= ret then
                    -- 此处缓存，加快下次访问。
                    rawset(sender,key,ret);
                    return ret;
                end
            end
        end,
        __newindex = function (sender,key,value)
            local property = cls.__w__[key];
            if property then
                property(sender,value);
                return;
            else
                if cls.__r__[key] then
                    -- 不能写入只读属性。
                    warn("You can't write a read-only property.")
                    return;
                end
            end
            rawset(sender,key,value);
        end
    };
    for k,v in pairs(ObjMeta) do
        meta[k] = v;
    end
    return meta;
end

--[[
    改造sol::usertype的元表，以适应lua-class的混合继承模式。
]]
local function RetrofitMeta(ud)
    local meta = getmetatable(ud);
    local retrofited = rawget(meta,"__lua_retrofit");
    -- 已改造过，跳过。
    if retrofited then
        return
    end
    local index = rawget(meta,"__index");
    local newIndex = rawget(meta,"__newindex");
    rawset(meta,"__index",function (sender,key)
        local uv,_ = debug.getuservalue(sender);
        -- 获取预先保存的lua类信息。
        local cls = uv.__cls__;
        if cls then
            -- 如果存在lua类的继承。
            --检查直接类的普通方法和成员等。
            local ret = rawget(cls,key);
            if nil ~= ret then
                return ret;
            end
            -- 检查属性。
            local property = cls.__r__[key];
            if property then
                return property(sender);
            else
                if cls.__w__[key] then
                    -- 不能读取只写属性。
                    warn("You can't read a write-only property.");
                    return nil;
                end
            end
            -- 检查基类。
            for _, base in ipairs(cls.__bases__) do
                ret = CascadeGet(base,key);
                if nil ~= ret then
                    -- 此处缓存，加快下次访问。
                    rawset(uv,key,ret);
                    return ret;
                end
            end
        end
        -- 最后检查sol::usertype定义的元方法。
        return index(sender,key);
    end);
    rawset(meta,"__newindex",function (sender,key,val)
        local uv,_ = debug.getuservalue(sender);
        -- 获取预先保存的lua类信息。
        local cls = uv.__cls__;
        if cls then
            local property = cls.__w__[key];
            if property then
                property(sender,val);
                return
            else
                if cls.__r__[key] then
                    -- 不能写入只读属性。
                    warn("You can't write a read-only property.");
                    return;
                end
            end
        end
        -- 最后检查sol::usertype定义的元方法。
        newIndex(sender,key,val);
    end);

    rawset(meta,"__lua_retrofit",true);
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
    local cls = self.is();

    local del = self[__del__];
    if del then
        del(self);
    end
    setmetatable(self,nil);
    self[DeathMarker] = true;
end

local BitsMap = {
    [Modifiers.Public] = 1 << 0,
    [Modifiers.Private] = 1 << 1,
    [Modifiers.Protected] = 1 << 2,
    [Modifiers.Static] = 1 << 3,
    [Modifiers.Const] = 1 << 4
};
local Router = nil;
if Debug then
    -- It is only under debug that the values need to be routed to the corresponding fields of the types.
    -- To save performance, all modifiers will be ignored under non-debug.
    Router = {};
    function Router:Begin(cls,key)
        rawset(self,"decor",0);
        rawset(self,"cls",cls);
        return self:Pass(key);
    end
    function Router:Pass(key)
        local bit = BitsMap[key];
        local decor = self.decor;
        if bit then
            if decor & bit ~= 0 then
                error(("The %s modifier is not reusable."):format(key));
            elseif decor & 0x7 ~= 0 and bit & 0x7 ~= 0 then
                -- Check Public,Private,Protected,they are 0x7
                error(("The %s modifier cannot be used in conjunction with other access modifiers."):format(key));
            end
            self.decor = decor | bit;
        else
            error(("There is no such modifier. - %s"):format(key));
        end
        return self;
    end
    function Router:End(key,value)
        local bit = BitsMap[key];
        if bit then
            error(("The name is unavailable. - %s"):format(key));
        end
        local decor = self.decor;
        if (decor & BitsMap[Modifiers.Static] ~= 0) and
        (key == __init__ or key == __del__) then
            error(("%s modifier cannot modify %s functions."):format(Modifiers.Static,key));
        elseif key == Handlers or key == Properties or key == Singleton or key == Friendly then
            error(("%s cannot be modified."):format(key));
        end
        local cls = self.cls;
        if decor & BitsMap[Modifiers.Public] ~= 0 then
            cls.__public__[key] = value;
        elseif decor & BitsMap[Modifiers.Private] ~= 0 then
            cls.__private__[key] = value;
        elseif decor & BitsMap[Modifiers.Protected] ~= 0 then
            cls.__protected__[key] = value;
        end
        if decor & BitsMap[Modifiers.Static] ~= 0 then
            cls.__static__[key] = value;
        end
        if decor & BitsMap[Modifiers.Const] ~= 0 then
            cls.__const__[key] = value;
        end
        self.decor = 0;
        self.cls = nil;
    end
    setmetatable(Router,{
        __index = function (self,key)
            return self:Pass(key);
        end,
        __newindex = function (self,key,val)
            self:End(key,val);
        end
    });
end

local function DebugClassGet(self,key)
    if BitsMap[key] then
        return Router:Begin(self,key);
    end
    -- Check the properties first.
    local property = self.__r__[key];
    if property then
        return property(self);
    else
        if self.__w__[key] then
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
    for _, base in ipairs(self.__bases__) do
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
        for __rw__,rw in pairs({__r__ = "r",__w__ = "w"}) do
            local subT = value[rw];
            if subT then
                for k,v in pairs(subT) do
                    self[__rw__][k] = v;
                end
            end
        end
    else
        local property = self.__w__[key];
        if property then
            property(self,value);
            return;
        else
            if self.__r__[key] then
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
        self.__public__[key] = value;
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
    local property = self.__r__[key];
    if property then
        return property(self);
    end
    for _, base in ipairs(self.__bases__) do
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
local rwTable = {__r__ = "r",__w__ = "w"};
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
        local property = self.__w__[key];
        return property and property(self,value) or rawset(self,key,value);
    end
end


local AllClasses = {};
local ClassCreateLayer = 0;
local ClassPermissions = nil;
function class.New(...)
    local cls = {
        -- All event handlers.
        [Handlers] = Debug and setmetatable({},HandlerMetaTable) or {},
        __bases__ = {},

        __public__ = Debug and {} or nil,
        __private__ = Debug and {} or nil,
        __protected__ = Debug and {} or nil,
        __const__ = Debug and {} or nil,
        __static__ = Debug and {} or nil,

        -- Represents the c++ base class of the class (and also the only c++ base class).
        __cpp_base__ = nil,

        -- function constructor in the index of the inheritance list, once the type has been constructed once,
        -- this field will be invalidated.
        __fCtorIdx__ = nil
    };

    local bases = cls.__bases__;
    local handlers = cls[Handlers];

    -- register meta-table of properties for class.
    for _,rw in pairs({"__r__","__w__"}) do
        cls[rw] = setmetatable({},{
            __index = function (_,key)
                for __,base in pairs(bases) do
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
                if nil == rawget(base,"__bases__") then
                    -- Inherite a simple table?
                    if AllowInheriteTable then
                        base.__r__ = {};
                        base.__w__ = {};
                        base.__bases__ = {};
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

    if not cls.__cpp_base__ then
        -- If the class is a pure lua class,
        -- provide a delete method to the class by default.

        -- If the class is a c++ class or inherited a c++ class,
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
        for _,base in pairs(bases) do
            if base.is(baseCls) then
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
    if Debug then
        cls.__public__[is] = _is;
    else
        cls[is] = _is;
    end

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
            local instance = nil;
            if __create__ then
                instance = cls.__create__(...);
                if instance then
                    local __fCtorIdx__ = rawget(cls,"__fCtorIdx__");
                    if __fCtorIdx__ then
                        local preCls = instance.__cls__;
                        if preCls then
                            -- After inserting the class to which the function constructor belongs into the multi-inheritance table,
                            -- __fCtorIdx__ can no longer be used.
                            rawset(cls,"__fCtorIdx__",nil);
                            table.insert(cls.__bases__,__fCtorIdx__,preCls);
                        end
                    end
                end
            else
                instance = {};
            end

            if nil == instance then
                ClassCreateLayer = ClassCreateLayer - 1;
                return nil;
            end

            local instType = type(instance);
            if ClassCreateLayer == 1 then
                if "table" == instType then
                    -- Instances of the table type do not require the last cls information
                    -- (which is already included in the metatable and in the upvalue).
                    instance.__cls__ = nil;
                    setmetatable(instance,meta);
                else
                    -- Instances of the userdata type require the last cls information.
                    local uv,_ = debug.getuservalue(instance);
                    uv.__cls__ = cls;
                    uv.is = _is;
                    RetrofitMeta(instance);
                end
                for key,func in pairs(handlers) do
                    -- Automatically listens to events.
                    Handler.On(key:sub(3),instance,func);
                end
            else
                if "table" == instType then
                    -- Returning cls together can indicate the class to which the function constructor belongs.
                    instance.__cls__ = cls;
                end
            end

            local init = cls[__init__];
            if init then
                -- Avoid recursively polluting the classCreateLayer variable when create a new object in the ctor.
                -- Cache it, after the call, set it to classCreateLayer+tempCreateLayer
                -- The final call ends with the value -1.
                local tempCreateLayer = ClassCreateLayer;
                ClassCreateLayer = 0;
                init(instance,...);
                ClassCreateLayer = ClassCreateLayer + tempCreateLayer - 1;
            else
                ClassCreateLayer = ClassCreateLayer - 1;
            end
            return instance;
        end;
        if Debug then
            -- In debug mode,the "new" method is public and static.
            cls.__public__[new] = new;
            cls.__static__[new] = new;
        else
            cls[new] = _new;
        end
    end

    setmetatable(cls,{
        __index = Debug and DebugClassGet or ClassGet,
        __newindex = Debug and DebugClassSet or ClassSet
    });

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

setmetatable(class,{
    __metatable = "Can't visit the metatable.",
    __call = function(c,...)
        return c.New(...)
    end
})