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

local Compat = require("OOP.Version.Compat");
local bits = Compat.bits;
local FunctionWrapper = Compat.FunctionWrapper;

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
local Friends = Config.Friends;
local Singleton = Config.Singleton;
local Properties = Config.Properties;
local Instance = Config.Instance;

local PropertyBehavior = Config.PropertyBehavior;
local ConstBehavior = Config.ConstBehavior;

local BaseClass = require("OOP.Variant.BaseClass");
local GetSingleton = BaseClass.GetSingleton;
local DestorySingleton = BaseClass.DestorySingleton;
local ObjMeta = BaseClass.ObjMeta;
local AccessStack = BaseClass.AccessStack;

local ReservedWord = {
    Public = Public,
    Protected = Protected,
    Private = Private,
    Const = Const,
    Static = Static
};

local function CheckClassAccessPermission(self,pm,key,byObj)
    if byObj and bits.band(pm,Permission.Static) ~= 0 then
        error(("Objects cannot access static members of a class. - %s"):format(key));
    end
    local friends = rawget(self,__friends__);
    local cls = AccessStack[#AccessStack];
    --Check if it is a friendly class.
    if not friends or not friends[cls] then
        if bits.band(pm,Permission.Public) == 0 then
            -- Check Public,Private,Protected.
            if cls ~= self then
                if bits.band(pm,Permission.Private) ~= 0 then
                    error(("Attempt to access private members outside the permission. - %s"):format(key));
                elseif bits.band(pm,Permission.Protected) ~= 0 and (not cls or not cls.is(self)) then
                    error(("Attempt to access protected members outside the permission. - %s"):format(key));
                end
            end
        end
    end
end

---Cascade to get the value of the corresponding key of a class and its base class
---(ignoring metamethods).
---
---@param self table
---@param key any
---@param byObj? boolean
---@return any
---
local function CascadeGet(self,key,byObj)
    local pm = self[__pm__][key];
    if pm then
        CheckClassAccessPermission(self,pm,key,byObj);
    end
    local ret = self[__all__][key];
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

local function GetFromClass(cls,key,sender)
    -- Check the key of current class first.
    local ret = rawget(cls,key);
    if nil ~= ret then
        return ret;
    end
    -- Check the properties of current class.
    local property = cls[__r__][key];
    if property then
        return property(sender);
    else
        if cls[__w__][key] then
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
    -- Check current class.
    local pm = cls[__pm__][key];
    if pm then
        CheckClassAccessPermission(cls,pm,key,true);
    end
    ret = cls[__all__][key];
    if nil ~= ret then
        return ret;
    end
    -- Check bases.
    for _, base in ipairs(cls[__bases__]) do
        ret = CascadeGet(base,key,true);
        if nil ~= ret then
            return ret;
        end
    end
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
            return GetFromClass(cls,key,sender);
        end,
        __newindex = function (sender,key,value)
            local property = cls[__w__][key];
            if property then
                property(sender,value);
                return;
            else
                if cls[__r__][key] then
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
    rawset(meta,"__index",function(sender,key)
        local uv = (debug.getuservalue(ud));
        local ret = GetFromClass(uv.__cls__,key,sender);
        if nil ~= ret then
            return ret;
        end
        -- Finally, check the original method.
        return index(sender,key);
    end);
    rawset(meta,"__newindex",function (sender,key,value)
        local uv = (debug.getuservalue(sender));
        local cls = uv.__cls__;
        local property = cls[__w__][key];
        if property then
            property(sender,value);
            return;
        else
            if cls[__r__][key] then
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
        -- Finally, write by the original method.
        newIndex(sender,key,value);
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
    local pm = self[__pm__][key];
    if pm then
        CheckClassAccessPermission(self,pm,key);
    end
    local ret = self[__all__][key];
    if nil ~= ret then
        return ret;
    end
    for _, base in ipairs(self[__bases__]) do
        ret = CascadeGet(base,key);
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
    if nil == value then
        self[__all__][key] = nil;
        self[__pm__][key] = nil;
        return;
    end
    local isFunction = "function" == type(value);
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
        assert(isFunction,("%s reserved word must be assigned to a function."):format(Singleton));
        -- Register "Instance" automatically.
        self[__r__][Instance] = function (cls)
            return GetSingleton(cls,value);
        end;
        self[__w__][Instance] = DestorySingleton;
        return;
    elseif key == Friends then
        assert(isFunction,("%s reserved word must be assigned to a function."):format(Friends));
        local friends = {};
        self[__friends__] = friends;
        for _, friend in ipairs({value()}) do
            friends[friend] = true;
        end
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
        if pm then
            if bits.band(pm,Permission.Const) ~= 0 then
                -- Check Const.
                if ConstBehavior ~= 2 then
                    if ConstBehavior == 0 then
                        if Version > 5.4 then
                            warn(("You cannot modify the Const value. - %s"):format(key));
                        end
                    elseif ConstBehavior == 1 then
                        error(("You cannot modify the Const value. - %s"):format(key));
                    end
                    return;
                end
            end
            CheckClassAccessPermission(self,pm,key);
        end
        pm = Permission.Public;
        if isFunction then
            -- Wrap this function to include control of access permission.
            value = FunctionWrapper(AccessStack,self,value);
        else
            -- Non-function types are static by default.
            pm = bits.bor(pm,Permission.Static);
        end
        self[__all__][key] = value;
        self[__pm__][key] = pm;
    end
end

return {
    MakeLuaObjMetaTable = MakeLuaObjMetaTable,
    RetrofitMeta = RetrofitMeta,
    ClassSet = ClassSet,
    ClassGet = ClassGet
};