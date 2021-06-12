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
local select = select;

local Config = require("OOP.Config");
local Debug = Config.Debug;
local Version = Config.Version;
local Alarm = Debug and error or (Version >= 5.4 and warn or print);

local __singleton__ = Config.__singleton__;

local is = Config.is;
local DeathMarker = Config.DeathMarker;

local Meta = Config.Meta;
local MetaDefault = Config.MetaDefault;
local __pairs__ = MetaDefault.__pairs;
local __len__ = MetaDefault.__len;
local __eq__ = MetaDefault.__eq;

local Null = Config.CppClass.Null;
local IsInherite = Config.CppClass.IsInherite;

local IsNull = Config.IsNull;

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
    for _,sender in ipairs({...}) do
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

---If there is no parameter,it means the return value is the current type.
---@return table
local function ClassIs(cls,bases,...)
    local len = select("#",...);
    if 0 == len then
        return cls;
    end
    local baseCls = select(1,...);
    if baseCls == nil then
        return false;
    end
    if baseCls == cls then
        return true;
    end
    for _,base in ipairs(bases) do
        local _is = rawget(base,is);
        if _is then
            if _is(baseCls) then
                return true;
            end
        elseif IsInherite and IsInherite(base,baseCls) then
            return true;
        end
    end
    return false;
end

local _IsNull = Null and function(t)
    local tt = type(t);
    if tt == "table" then
        return rawget(t,DeathMarker);
    elseif tt == "userdata" then
        return Null(t);
    end
    return not t;
end or
function(t)
    if type(t) == "table" then
        return rawget(t,DeathMarker);
    end
    return not t;
end;
class[IsNull] = _IsNull;

---Get the single instance, where it is automatically judged empty
---and does not require the user to care.
---
---@param self any
---@param call function
---
local function GetSingleton(self,call)
    local s = rawget(self,__singleton__);
    if _IsNull(s) then
        s = call();
        rawset(self,__singleton__,s);
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
        local s = rawget(self,__singleton__);
        if not _IsNull(s) then
            s:delete();
            rawset(self,__singleton__,nil);
        end
    end
end

---Copy any value.
---
---@param any any
---@return any
---
local function Copy(any,existTab)
    existTab = existTab or {}
    if type(any) ~= "table" then
        return any;
    elseif nil ~= existTab[any] then
        return existTab[any];
    end

    local tempTab = {};
    existTab[any] = tempTab;
    for k,v in pairs(any) do
        tempTab[Copy(k,existTab)] = Copy(v,existTab);
    end
    return tempTab;
end

setmetatable(class,{
    __call = function(c,...)
        return c.New(...)
    end
});
rawset(_G,Config.class,class);

return {
    class = class,
    ObjMeta = ObjMeta,
    GetSingleton = GetSingleton,
    DestorySingleton = DestorySingleton,
    ClassIs = ClassIs,
    IsNull = _IsNull,
    AllClasses = {},
    Copy = Copy,
    AccessStack = Debug and {} or nil
};