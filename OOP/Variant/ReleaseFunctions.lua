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
local rawset = rawset;
local pairs = pairs;
local ipairs = ipairs;

local Config = require("OOP.Config");

local R = require("OOP.Router")
local BitsMap = R.BitsMap;

local __r__ = Config.__r__;
local __w__ = Config.__w__;
local __bases__ = Config.__bases__;

local Properties = Config.Properties;


local Cache = Config.Cache;

local BaseClass = require("OOP.Variant.BaseClass");
local ObjMeta = BaseClass.ObjMeta;
local CascadeGet = BaseClass.CascadeGet;

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

local rwTable = {[__r__] = "r",[__w__] = "w"};
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

return {
    MakeLuaObjMetaTable = MakeLuaObjMetaTable,
    RetrofitMeta = RetrofitMeta,
    ClassSet = ClassSet,
    ClassGet = ClassGet
};