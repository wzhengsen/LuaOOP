-- Copyright (c) 2021 榆柳松
-- https://github.com/wzhengsen/LuaOOP

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

local Config = require("OOP.Config");
local i18n = require("OOP.i18n");
local LuaVersion = Config.LuaVersion;
local Compat1 = LuaVersion < 5.3 and require("OOP.Version.LowerThan53") or require("OOP.Version.HigherThan52");
local Compat2 = LuaVersion < 5.4 and require("OOP.Version.LowerThan54") or require("OOP.Version.HigherThan53");
local Internal = require("OOP.Variant.Internal");
local ClassesChildren = Internal.ClassesChildren;
local ClassesBases = Internal.ClassesBases;
local ClassesFriends = Internal.ClassesFriends;
local NamedClasses = Internal.NamedClasses;
local Permission = Internal.Permission;
local Debug = Config.Debug;
local IsInherite = Config.ExternalClass.IsInherite;


local ipairs = ipairs;
local pairs = pairs;
local type = type;
local getmetatable = getmetatable;
local rawequal = rawequal;

---Maps some value changes to subclasses.
---@param cls table
---@param keyTable table
---@param value any
local function Update2Children(cls,keyTable,value)
    local children = ClassesChildren[cls];
    for _,child in ipairs(children) do
        if nil == keyTable[child] then
            keyTable[child] = value;
        end
        Update2Children(child,keyTable,value);
    end
end

local function Update2ChildrenWithKey(cls,keyTable,key,value,force)
    local children = ClassesChildren[cls];
    for _,child in ipairs(children) do
        local t = keyTable[child];
        if t and force or nil == t[key] then
            t[key] = value;
        end
        Update2ChildrenWithKey(child,keyTable,key,value);
    end
end

local function Update2ChildrenClassMeta(cls,key,value)
    local children = ClassesChildren[cls];
    for _,child in ipairs(children) do
        local cmt = getmetatable(child);
        if cmt and nil == cmt[key]  then
            cmt[key] = value;
        end
        Update2ChildrenClassMeta(child,key,value);
    end
end

local function _Copy(any,existTab)
    if type(any) ~= "table" then
        return any;
    end
    local ret = existTab[any];
    if nil ~= ret then
        return ret;
    end

    local tempTab = {};
    existTab[any] = tempTab;
    for k,v in pairs(any) do
        tempTab[_Copy(k,existTab)] = _Copy(v,existTab);
    end
    return tempTab;
end

---Copy any value.
---
---@param any any
---@return any
---
local Copy = function (any)
    return _Copy(any,{});
end

local function ClassBasesIsRecursive(baseCls,bases)
    for _,base in ipairs(bases) do
        if rawequal(base,baseCls) then
            return true;
        else
            local bBases = ClassesBases[base];
            if bBases and ClassBasesIsRecursive(baseCls,bBases) then
                return true;
            elseif IsInherite and IsInherite(base,baseCls) then
                return true;
            end
        end
    end
    return false;
end

local CheckPermission = nil;

if Debug then
    local ClassesPermissions = Internal.ClassesPermissions;
    local AccessStack = Internal.AccessStack;
    local ConstStack = Internal.ConstStack;
    local band = Compat1.bits.band;
    local ConstBehavior = Config.ConstBehavior;
    local p_const = Permission.const;
    local p_public = Permission.public;
    local p_protected = Permission.protected;
    local p_private = Permission.private;
    local p_internalConstMethod = Internal.BitsMap.__InternalConstMethod;

    ---Cascade to get permission values up to the top of the base class.
    ---
    ---@param self table
    ---@param key any
    ---@return table,integer
    ---
    local function CascadeGetPermission(self,key)
        local pms = ClassesPermissions[self];
        local pm = pms and pms[key] or nil;
        local cls = self;
        if nil == pm then
            local bases = ClassesBases[self];
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
    ---@param set? boolean
    ---@return boolean
    ---
    CheckPermission = function(self,key,set)
        local stackCls = AccessStack[#AccessStack];
        if stackCls == 0 then
            -- 0 means that any access rights can be broken.
            return true;
        end
        local cls,pm = CascadeGetPermission(self,key);

        local constMethod = pm and band(pm,p_internalConstMethod) ~= 0 or false;
        if set and not constMethod then
            -- Const methods have unique semantics, rather than representing constants.
            -- Therefore, const methods are allowed to be reassigned.
            if pm and
            band(pm,p_const) ~= 0 or
            (ConstStack[#ConstStack] and (rawequal(stackCls,self) or ClassBasesIsRecursive(stackCls,ClassesBases[self]))) then
                -- Check const.
                if ConstBehavior ~= 2 then
                    if ConstBehavior == 0 then
                        warn(("You cannot change the const value. - %s"):format(key:sub(2)));
                    elseif ConstBehavior == 1 then
                        error((i18n"You cannot change the const value. - %s"):format(key:sub(2)));
                    end
                    return false;
                end
            end
        end

        if not pm then
            return true;
        end

        if band(pm,p_public) ~= 0 then
            -- Allow public.
            return true;
        end
        if rawequal(stackCls,cls) then
            return true;
        end

        -- Why is it necessary to determine once more whether the current class is the base class of the current instance?
        -- Consider following code:
        -- local Base = class();
        -- function Base:ctor(data)
        --     self.data = data;-- In LuaOOP, any unspecified field is public, so it should be implemented correctly here.
        -- end
        -- local Protected = class(Base);
        -- Protected.protected.data = 0;
        -- local p = Protected.new(1);-- Here Base.ctor(self,1) will be called. Without the following code, an error will be raised in the Base.ctor function to access the protected field.
        local bases = ClassesBases[cls];
        if bases and stackCls and ClassBasesIsRecursive(stackCls,bases) then
            return true;
        end

        local _friends = ClassesFriends[cls];
        --Check if it is a friendly class.
        if not _friends or (not _friends[stackCls] and not _friends[NamedClasses[stackCls]]) then
            -- Check public,private,protected.
            if band(pm,p_private) ~= 0 then
                error((i18n"Attempt to access private members outside the permission. - %s"):format(key:sub(2)));
            elseif band(pm,p_protected) ~= 0 then
                if stackCls then
                    bases = ClassesBases[stackCls];
                    if bases and ClassBasesIsRecursive(cls,bases) then
                        return true;
                    end
                end
                error((i18n"Attempt to access protected members outside the permission. - %s"):format(key:sub(2)));
            end
        end
        return true;
    end
end

return {
    bits = Compat1.bits,
    FunctionWrapper = Compat2.FunctionWrapper,
    BreakFunctionWrapper = Compat2.BreakFunctionWrapper,
    Update2Children = Update2Children,
    Update2ChildrenWithKey = Update2ChildrenWithKey,
    Update2ChildrenClassMeta = Update2ChildrenClassMeta,
    CheckPermission = CheckPermission,
    ClassBasesIsRecursive = ClassBasesIsRecursive,
    Copy = Copy
};