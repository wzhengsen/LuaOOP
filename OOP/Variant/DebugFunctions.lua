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

local new = Config.new;
local delete = Config.delete;
local is = Config.is;
local __r__ = Config.__r__;
local __w__ = Config.__w__;
local __bases__ = Config.__bases__;
local __all__ = Config.__all__;
local __pm__ = Config.__pm__;
local __friends__ = Config.__friends__;
local __del__ = Config.__del__;
local __cls__ = Config.__cls__;
local __members__ = Config.__members__;
local __meta__ = Config.__meta__;

local Public = Config.Modifiers.Public;
local Protected = Config.Modifiers.Protected;
local Private = Config.Modifiers.Private;
local Const = Config.Modifiers.Const;
local Static = Config.Modifiers.Static;
local Friends = Config.Friends;
local Singleton = Config.Singleton;
local Properties = Config.Properties;
local Instance = Config.Instance;

local IsCppClass = Config.CppClass.IsCppClass;
local DeathMarker = Config.DeathMarker;

local MetaMapName = Config.MetaMapName;

local PropertyBehavior = Config.PropertyBehavior;
local ConstBehavior = Config.ConstBehavior;

local BaseClass = require("OOP.Variant.BaseClass");
local GetSingleton = BaseClass.GetSingleton;
local DestorySingleton = BaseClass.DestorySingleton;
local AccessStack = BaseClass.AccessStack;
local AllClasses = BaseClass.AllClasses;

local ReservedWord = {
    Public = Public,
    Protected = Protected,
    Private = Private,
    Const = Const,
    Static = Static
};

---Cascade to get permission values up to the top of the base class.
---
---@param self table
---@param key any
---@return table,integer
---
local function CascadeGetPermission(self,key)
    local pms = rawget(self,__pm__);
    local pm = pms and pms[key] or nil;
    local cls = self;
    if nil == pm then
        local bases = rawget(self,__bases__);
        if bases then
            for _,base in ipairs(bases) do
                cls,pm = CascadeGetPermission(base,key);
                if nil ~= pm then
                    return cls,pm;
                end
            end
        end
    end
    return cls,pm;
end

---When a member is accessed directly as a class,
---the members will be checked cascading.
---
---@param self table
---@param key any
---@param byObj boolean
---@param set? boolean
---@return boolean
---
local function CheckPermission(self,key,byObj,set)
    local cls,pm = CascadeGetPermission(self,key);
    if not pm then
        return true;
    end
    local stackCls = AccessStack[#AccessStack];
    if stackCls == 0 and bits.band(pm,Permission.Protected) ~= 0 then
        return true;
    end
    if byObj and bits.band(pm,Permission.Static) ~= 0 then
        error(("Objects cannot access static members of a class. - %s"):format(key));
    end
    if set then
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
                return false;
            end
        end
        -- When a class performs a set operation,
        -- even if the operation is on a private member,
        -- it is considered to be a redefinition and the operation is not disabled.
        if not byObj then
            return true;
        end
    end
    local friends = rawget(cls,__friends__);
    --Check if it is a friendly class.
    if not friends or (not friends[stackCls] and not friends[AllClasses[stackCls]]) then
        if bits.band(pm,Permission.Public) == 0 then
            -- Check Public,Private,Protected.
            if stackCls ~= cls then
                if bits.band(pm,Permission.Private) ~= 0 then
                    error(("Attempt to access private members outside the permission. - %s"):format(key));
                elseif bits.band(pm,Permission.Protected) ~= 0 and (not stackCls or not stackCls.is(cls)) then
                    error(("Attempt to access protected members outside the permission. - %s"):format(key));
                end
            end
        end
    end
    return true;
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

        local pm = cls[__pm__][__del__];
        if pm then
            local friends = rawget(cls,__friends__);
            local aCls = AccessStack[#AccessStack];
            if (not friends or (not friends[aCls] and not friends[AllClasses[cls]])) and
            (bits.band(pm,Permission.Public) == 0) and
            (aCls ~= cls) and
            (bits.band(pm,Permission.Private) ~= 0)then
                error(("Attempt to access private members outside the permission. - %s"):format(__del__));
            end
        end

        del = cls[__all__][__del__];
    end
    if del then
        del(self);
    end
    called[cls] = true;
end

local DefaultDelete = function(self)
    CascadeDelete(self,self[is](),{});
    setmetatable(self,nil);
    self[__all__] = nil;
    self[DeathMarker] = true;
end

---Cascade to get the value of the corresponding key of a class and its base class
---(ignoring metamethods).
---
---@param self table
---@param key any
---@return any
---
local function CascadeGet(self,key)
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

local function GetAndCheck(cls,key,sender)
    if not CheckPermission(cls,key,true) then
        return nil;
    end
    -- Check self __all__ first.
    local ret = sender[__all__][key];
    if nil ~= ret then
        return ret;
    end
    -- Check the key of current class.
    ret = rawget(cls,key);
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
    ret = cls[__all__][key];
    if nil ~= ret then
        return ret;
    end
    -- Check bases.
    for _, base in ipairs(cls[__bases__]) do
        ret = CascadeGet(base,key);
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
    local clsMeta = cls[__meta__];
    local meta = clsMeta[__meta__];
    if nil == meta then
        meta = {
            __index = function (sender,key)
                return GetAndCheck(cls,key,sender);
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
                if not CheckPermission(cls,key,true,true) then
                    return;
                end
                rawset(sender[__all__],key,value);
            end
        };
        for k,v in pairs(clsMeta) do
            if k ~= __meta__ then
                meta[k] = v;
            end
        end
        clsMeta[__meta__] = meta;
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
        local cls = uv[__cls__];
        local ret = GetAndCheck(cls,key,sender);
        if nil ~= ret then
            return ret;
        end
        -- Finally, check the original method.
        return index(sender,key);
    end);
    rawset(meta,"__newindex",function (sender,key,value)
        local uv = (debug.getuservalue(sender));
        local cls = uv[__cls__];
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
        if not CheckPermission(cls,key,true,true) then
            return;
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
    if not CheckPermission(self,key,false) then
        return;
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
    local isFunction = "function" == type(value);
    if key == Properties then
        value = value(self);
        -- Register properties.
        for __rw__,rw in pairs(rwTable) do
            local subT = value[rw];
            if subT then
                for k,v in pairs(subT) do
                    self[__rw__][k] = FunctionWrapper(AccessStack,self,v);
                end
            end
        end
        return;
    elseif key == Singleton then
        assert(isFunction,("%s reserved word must be assigned to a function."):format(Singleton));
        -- Register "Instance" automatically.
        self[__r__][Instance] = FunctionWrapper(AccessStack,self,function()
            return GetSingleton(self,value);
        end);
        self[__w__][Instance] = FunctionWrapper(AccessStack,self,function(_,val)
            DestorySingleton(self,val)
        end);
        -- Once register "Singleton" for a class,set permission of "new","delete" method to protected.
        local pm = self[__pm__][new];
        if bits.band(pm,Permission.Private) == 0 then
            self[__pm__][new] = Permission.Static + Permission.Protected;
        end
        self[__pm__][delete] = Permission.Protected;
        return;
    elseif key == Friends then
        assert(isFunction,("%s reserved word must be assigned to a function."):format(Friends));
        local friends = {};
        rawset(self,__friends__,friends);
        value = FunctionWrapper(AccessStack,self,value);
        for _, friend in ipairs({value(self)}) do
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
        if not CheckPermission(self,key,false,true) then
            return;
        end
        local exist = self[__all__][key];
        if not exist then
            if not isFunction then
                self[__members__][key] = value;
            end
            self[__pm__][key] = Permission.Public;
        end
        if isFunction then
            -- Wrap this function to include control of access permission.
            value = FunctionWrapper(AccessStack,self,value);
        end
        self[__all__][key] = value;
    end
    local meta = MetaMapName[key];
    if meta then
        self[__meta__][meta] = value;
        self[__meta__][__meta__] = nil;
    end
end

return {
    MakeLuaObjMetaTable = MakeLuaObjMetaTable,
    RetrofitMeta = RetrofitMeta,
    ClassSet = ClassSet,
    ClassGet = ClassGet,
    DefaultDelete = DefaultDelete
};