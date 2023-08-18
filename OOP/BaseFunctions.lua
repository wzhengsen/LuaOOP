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
local Internal = require("OOP.Variant.Internal");
local ClassesChildren = Internal.ClassesChildren;
local ClassesBases = Internal.ClassesBases;
local ClassesFriends = Internal.ClassesFriends;
local AllFunctions = Internal.ClassesAllFunctions;
local ClassesFunctionDefined = Internal.ClassesFunctionDefined;
local NamedClasses = Internal.NamedClasses;
local Permission = Internal.Permission;
local Debug = Config.Debug;
local IsInherite = Config.ExternalClass.IsInherite;

local ipairs = ipairs;
local pairs = pairs;
local type = type;
local getmetatable = getmetatable;
local rawequal = rawequal;
local getinfo = debug.getinfo;

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

local function ClassBasesIsRecursive(baseCls, bases)
    for _, base in ipairs(bases) do
        if rawequal(base, baseCls) then
            return true;
        else
            local bBases = ClassesBases[base];
            if bBases and ClassBasesIsRecursive(baseCls, bBases) then
                return true;
            elseif IsInherite and IsInherite(base, baseCls) then
                return true;
            end
        end
    end
    return false;
end

local function DefinedInClass(info, cls)
    local src = info.short_src;
    local defined = ClassesFunctionDefined[cls][src];
    if defined then
        local def = info.linedefined;
        for i = 1, #defined, 2 do
            if def >= defined[i] and def <= defined[i + 1] then
                return true;
            end
        end
    end
    return false;
end

local function DefinedInClasses(info, cls)
    if DefinedInClass(info, cls) then
        return true;
    end
    for _, child in ipairs(ClassesChildren[cls]) do
        if DefinedInClasses(info, child) then
            return true;
        end
    end
    return false;
end

local CheckPermission = nil;
local FunctionWrapper = nil;
local BreakFunctionWrapper = nil;

if Debug then
    local ClassesPermissions = Internal.ClassesPermissions;
    local AccessStack = Internal.AccessStack;
    local ConstStack = Internal.ConstStack;
    local AccessStackLen = AccessStack and #AccessStack or nil;
    local ConstStackLen = ConstStack and #ConstStack or nil;
    local ConstBehavior = Config.ConstBehavior;
    local p_const = Permission.const;
    local p_mutable = Permission.mutable;
    local p_public = Permission.public;
    local p_protected = Permission.protected;
    local p_private = Permission.private;
    local p_internalConstMethod = Internal.__InternalConstMethod;

    local RAII = setmetatable({}, {
        __close = function()
            AccessStack[AccessStackLen] = nil;
            AccessStackLen = AccessStackLen - 1;
            ConstStack[ConstStackLen] = nil;
            ConstStackLen = ConstStackLen - 1;
        end
    });

    ---
    ---Wrapping the given function so that it handles the push and pop of the access stack correctly anyway,
    ---to avoid the access stack being corrupted by an error being thrown in one of the callbacks.
    ---@param cls table
    ---@param f function
    ---@param clsFunctions? table
    ---@param const? boolean
    ---@return function
    ---
    function FunctionWrapper(cls, f, clsFunctions, const)
        clsFunctions = clsFunctions or AllFunctions[cls];
        local newF = clsFunctions[f];
        if nil == newF then
            -- Records information about the definition of a function,
            -- which is used to determine whether a closure is defined
            -- in a function of the corresponding class.
            local fInfo = getinfo(f, "S");
            if fInfo.what ~= "C" then
                if ClassesFunctionDefined[cls] == nil then
                    ClassesFunctionDefined[cls] = {};
                end
                if ClassesFunctionDefined[cls][fInfo.short_src] == nil then
                    ClassesFunctionDefined[cls][fInfo.short_src] = {};
                end
                local defined = ClassesFunctionDefined[cls][fInfo.short_src];
                defined[#defined + 1] = fInfo.linedefined;
                defined[#defined + 1] = fInfo.lastlinedefined;
            end
            newF = function(...)
                AccessStackLen = AccessStackLen + 1;
                AccessStack[AccessStackLen] = cls;
                ConstStackLen = ConstStackLen + 1;
                ConstStack[ConstStackLen] = const or false;

                local _ <close> = RAII;
                if ConstStackLen > 1 and ConstStack[ConstStackLen - 1] and not const then
                    local lastCls = AccessStack[ConstStackLen - 1];
                    if lastCls ~= 0 and cls ~= 0 and lastCls[is](cls) then
                        error(i18n "Cannot call a non-const method on a const method.");
                    end
                end
                return f(...);
            end;
            clsFunctions[newF] = newF;
            clsFunctions[f] = newF;
        end
        return newF;
    end

    local BreakFunctions = setmetatable({}, Internal.WeakTable);
    function BreakFunctionWrapper(f)
        -- 0 means that any access permissions can be broken.
        return FunctionWrapper(0, f, BreakFunctions);
    end
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
    ---@param callLvl integer
    ---@param set? boolean
    ---@param byObj? boolean
    ---@return boolean
    ---
    CheckPermission = function(self, key, callLvl, set, byObj)
        local stackCls = AccessStack[#AccessStack];
        if stackCls == 0 then
            -- 0 means that any access rights can be broken.
            return true;
        end
        local cls,pm = CascadeGetPermission(self,key);

        local constMethod = pm and (pm & p_internalConstMethod) ~= 0 or false;
        if set and not constMethod then
            -- Const methods have unique semantics, rather than representing constants.
            -- Therefore, const methods are allowed to be reassigned.
            if pm and
            (pm & p_const) ~= 0 or
            (ConstStack[#ConstStack] and (rawequal(stackCls,self) or ClassBasesIsRecursive(stackCls,ClassesBases[self]))) then
                -- Check const.
                if pm & p_mutable == 0 then
                    if ConstBehavior ~= 2 then
                        if ConstBehavior == 0 then
                            warn(i18n "You cannot change the const value. - %s":format(key:sub(2)));
                        elseif ConstBehavior == 1 then
                            error(i18n "You cannot change the const value. - %s":format(key:sub(2)));
                        end
                        return false;
                    end
                end
            end
            -- Consider the following case.
            -- local A = class();
            -- function A.protected:ctor()end
            -- function A.protected:dtor()end
            -- local B = class(A);
            -- function B:ctor()end-- Allowed.
            -- function B.protected:dtor()end-- Allowed.
            -- function B:dtor()end -- Raise error at here.
            if not byObj and not rawequal(cls,self) then
                return true;
            end
        end

        if not pm then
            return true;
        end

        if pm & p_public ~= 0 then
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

        -- 0 - OK
        -- 1 - private error
        -- 2 - protected error
        local status = 0;
        local _friends = ClassesFriends[cls];
        --Check if it is a friendly class.
        if not _friends or (not _friends[stackCls] and not _friends[NamedClasses[stackCls]]) then
            -- Check public,private,protected.
            if pm & p_private ~= 0 then
                status = 1;
            elseif pm & p_protected ~= 0 then
                if stackCls then
                    bases = ClassesBases[stackCls];
                    if bases and ClassBasesIsRecursive(cls, bases) then
                        return true;
                    end
                end
                status = 2;
            end

            -- If a field's permission check fails, the lines of definition of the code accessing
            -- the field are again used to determine whether it should pass.
            -- If a lua function (or closure) that accesses a field is defined in a class that has permission
            -- to access the field, then the field access permissions in that closure should also pass.
            --
            -- Defects:
            -- When a closure is defined outside of a class, but on the same line as a function of the class,
            -- access permissions within the closure will not be properly determined.
            local info = getinfo(callLvl, "S");
            if info.what ~= "C" then
                if DefinedInClass(info, cls) then
                    return true;
                elseif status ~= 1 then
                    if byObj then
                        if not rawequal(self, cls) then
                            if DefinedInClass(info, self) then
                                return true;
                            end
                        end
                    else
                        for _, child in ipairs(ClassesChildren[cls]) do
                            if DefinedInClasses(info, child) then
                                return true;
                            end
                        end
                    end
                end
            end
        end

        if status == 1 then
            error((i18n "Attempt to access private members outside the permission. - %s"):format(key:sub(2)));
        elseif status == 2 then
            error((i18n "Attempt to access protected members outside the permission. - %s"):format(key:sub(2)));
        end
        return true;
    end
end

return {
    FunctionWrapper = FunctionWrapper,
    BreakFunctionWrapper = BreakFunctionWrapper,
    Update2Children = Update2Children,
    Update2ChildrenWithKey = Update2ChildrenWithKey,
    Update2ChildrenClassMeta = Update2ChildrenClassMeta,
    CheckPermission = CheckPermission,
    ClassBasesIsRecursive = ClassBasesIsRecursive,
    Copy = Copy
};