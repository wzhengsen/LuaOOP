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
local Version = Config.Version;

local bits = (Version < 5.3 and require("OOP.Compat.LowerThan53") or require("OOP.Compat.HigherThan52")).bits;

local R = require("OOP.Router");
local Router = R.Router;
local BitsMap = R.BitsMap;
local Permission = R.Permission;

local __r__ = Config.__r__;
local __w__ = Config.__w__;
local __bases__ = Config.__bases__;
local __all__ = Config.__all__;
local __pm__ = Config.__pm__;
local __friends__ = Config.__friends__;

local Public = Config.Modifiers.Public;
local Protected = Config.Modifiers.Protected;
local Private = Config.Modifiers.Private;
local Const = Config.Modifiers.Const;
local Static = Config.Modifiers.Static;
local Handlers = Config.Handlers;
local Friends = Config.Friends;
local Singleton = Config.Singleton;
local Properties = Config.Properties;
local Instance = Config.Instance;

local PropertyBehavior = Config.PropertyBehavior;

local BaseClass = require("OOP.Variant.BaseClass");
local CascadeGet = BaseClass.CascadeGet;
local GetSingleton = BaseClass.GetSingleton;
local DestorySingleton = BaseClass.DestorySingleton;

local ReservedWord = {
    Public = Public,
    Protected = Protected,
    Private = Private,
    Const = Const,
    Static = Static
};

---
---Generate a meta-table for an object (typically a table) generated by a pure lua class.
---
---@param cls table
---@return table
---
local function MakeLuaObjMetaTable(cls)
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
local function ClassGet(self,key)
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
                if PropertyBehavior == 0 then
                    if Version > 5.4 then
                        warn("You can't read a write-only property.");
                    end
                elseif PropertyBehavior == 1 then
                    error("You can't read a write-only property.");
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
local function ClassSet(self,key,value)
    -- The reserved words cannot be used.
    if ReservedWord[key] then
        error(("%s is a reserved word and you can't use it."):format(key));
    end
    if key == Properties then
        value = value(self);
        -- Register properties.
        for __rw__,rw in pairs(rwTable) do
            local subT = value[rw];
            if subT then
                for k,v in pairs(subT) do
                    self[__rw__][k] = v;
                end
            end
        end
        return;
    elseif key == Singleton then
        assert("function" == type(value),("%s reserved word must be assigned to a function."):format(Singleton));
        -- Register "Instance" automatically.
        self[__r__][Instance] = function (cls)
            return GetSingleton(cls,value);
        end;
        self[__w__][Instance] = DestorySingleton;
        return;
    elseif key == Friends then
        assert("function" == type(value),("%s reserved word must be assigned to a function."):format(Friends));
        self[__friends__] = {value()};
        return;
    else
        local property = self[__w__][key];
        if property then
            property(self,value);
            return;
        else
            if self[__r__][key] then
                if PropertyBehavior ~= 2 then
                    if PropertyBehavior == 0 then
                        if Version > 5.4 then
                            warn("You can't write a read-only property.");
                        end
                    elseif PropertyBehavior == 1 then
                        error("You can't write a read-only property.");
                    end
                    return;
                end
            end
        end
        local pm = self[__pm__][key];
        if pm and bits.band(pm,Permission.Const) then
            error(("You cannot modify the Const value. - %s"):format(key));
        end
        self[__all__][key] = value;
        -- No modifier is assigned here; no modifier means Public.
    end
end

return {
    MakeLuaObjMetaTable = MakeLuaObjMetaTable,
    RetrofitMeta = RetrofitMeta,
    ClassSet = ClassSet,
    ClassGet = ClassGet
};