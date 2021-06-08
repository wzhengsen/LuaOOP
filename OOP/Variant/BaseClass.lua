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
local type = type;

local Config = require("OOP.Config");
local Debug = Config.Debug;
local Version = Config.Version;
local Alarm = Debug and error or (Version >= 5.4 and warn or print);

local __bases__ = Config.__bases__;
local __del__ = Config.__del__;
local __singleton__ = Config.__singleton__;

local is = Config.is;
local DeathMarker = Config.DeathMarker;

local Meta = Config.Meta;
local MetaDefault = Config.MetaDefault;
local __pairs__ = MetaDefault.__pairs;
local __len__ = MetaDefault.__len;
local __eq__ = MetaDefault.__eq;

local Null = Config.CppClass.Null;
local IsCppClass = Config.CppClass.IsCppClass;

local class = {};

-- Object's meta-table implementation.
local ObjMeta = {};
for meta, name in pairs(Meta)do
    ObjMeta[meta] = function (self,...)
        local f = self[name];
        if f then
            return meta(self,...);
        end
        -- If you use an operation that is not implemented, an warn will be raised.
        Alarm(("You must implement the %s meta-method."):format(name));
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

local DefaultDelete = function(self)
    CascadeDelete(self,self[is](),{});
    setmetatable(self,nil);
    self[DeathMarker] = true;
end

---Get the single instance, where it is automatically judged empty
---and does not require the user to care.
---
---@param self any
---@param call function
---
local function GetSingleton(self,call)
    local s = self[__singleton__];
    if class.IsNull(s) then
        s = call();
        self[__singleton__] = s;
    end
    return s;
end

---Destroy the single instance.
---It is mapped to Instance property.
---
---@param self table
---@param val nil   This parameter must be a nil value.
---
local function DestorySingleton(self,val)
    assert(
        not Debug or nil == val,
        "The nil value needs to be passed in to destory the object."
    );
    if nil == val then
        local s = self[__singleton__];
        if not class.IsNull(s) then
            s:delete();
            self[__singleton__] = nil;
        end
    end
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
    __call = function(c,...)
        return c.New(...)
    end
});
rawset(_G,Config.class,class);

return {
    class = class,
    ObjMeta = ObjMeta,
    DefaultDelete = DefaultDelete,
    CascadeGet = CascadeGet,
    GetSingleton = GetSingleton,
    DestorySingleton = DestorySingleton,
    AllClasses = {},
    AccessList = {}
};