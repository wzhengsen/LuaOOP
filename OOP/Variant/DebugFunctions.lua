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
local On = Config.On;
local __del__ = Config.__del__;

local Public = Config.Modifiers.Public;
local Protected = Config.Modifiers.Protected;
local Private = Config.Modifiers.Private;
local Const = Config.Modifiers.Const;
local Static = Config.Modifiers.Static;
local Friends = Config.Friends;
local Singleton = Config.Singleton;
local Properties = Config.Properties;
local Instance = Config.Instance;
local Handlers = Config.Handlers;

local IsCppClass = Config.CppClass.IsCppClass;
local DeathMarker = Config.DeathMarker;

local MetaMapName = Config.MetaMapName;

local PropertyBehavior = Config.PropertyBehavior;
local ConstBehavior = Config.ConstBehavior;

local Functions = require("OOP.Variant.BaseFunctions");
local GetSingleton = Functions.GetSingleton;
local DestroySingleton = Functions.DestroySingleton;
local CreateClassObject = Functions.CreateClassObject;
local AllClasses = Functions.AllClasses;
local ClassesReadable = Functions.ClassesReadable;
local ClassesWritable = Functions.ClassesWritable;
local ClassesHandlers = Functions.ClassesHandlers;
local ClassesBases = Functions.ClassesBases;
local ClassesMembers = Functions.ClassesMembers;
local ClassesMetas = Functions.ClassesMetas;
local ClassesCreate = Functions.ClassesCreate;
local ClassesCppBase = Functions.ClassesCppBase;
local ClassesCtorIndex = Functions.ClassesCtorIndex;
local ObjectsAll = Functions.ObjectsAll;
local ObjectsCls = Functions.ObjectsCls;
local CheckClassName = Functions.CheckClassName;
local PushBase = Functions.PushBase;
local CreateClassTables = Functions.CreateClassTables;

local ClassesAll = Functions.ClassesAll;
local ClassesPermisssions = Functions.ClassesPermisssions;
local ClassesFriends = Functions.ClassesFriends;
local AccessStack = Functions.AccessStack;

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
    local pms = ClassesPermisssions[self];
    local pm = pms and pms[key] or nil;
    local cls = self;
    if nil == pm then
        local bases = ClassesBases[self];
        for _,base in ipairs(bases) do
            cls,pm = CascadeGetPermission(base,key);
            if nil ~= pm then
                return cls,pm;
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
    local friends = ClassesFriends[cls];
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


---Cascade to get the value of the corresponding key of a class and its base class
---(ignoring metamethods).
---
---@param self table
---@param key any
---@return any
---
local function CascadeGet(self,key)
    local all = ClassesAll[self];
    if nil == all then
        return;
    end
    local ret = all[key];
    if nil ~= ret then
        return ret;
    end
    local bases = ClassesBases[self];
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
    local ret = ObjectsAll[sender][key];
    if nil ~= ret then
        return ret;
    end
    -- Check the key of current class.
    ret = rawget(cls,key);
    if nil ~= ret then
        return ret;
    end
    -- Check the properties of current class.
    local property = ClassesReadable[cls][key];
    if property then
        return property(sender);
    else
        if ClassesWritable[cls][key] then
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
    ret = ClassesAll[cls][key];
    if nil ~= ret then
        return ret;
    end
    -- Check bases.
    for _, base in ipairs(ClassesBases[cls]) do
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
local function MakeTableObjectMeta(cls)
    local meta = ClassesMetas[cls];
    if nil == rawget(meta,"__index") then
        meta.__index = function (sender,key)
            return GetAndCheck(cls,key,sender);
        end;
        meta.__newindex = function (sender,key,value)
            local property = ClassesWritable[cls][key];
            if property then
                property(sender,value);
                return;
            else
                if ClassesReadable[cls][key] then
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
            rawset(ObjectsAll[sender],key,value);
        end
    end
    return meta;
end

---
--- Retrofit userdata's meta-table to fit lua-class's hybrid inheritance pattern.
---
---@param obj userdata
---
local function RetrofitMeta(obj)
        -- Unlike the normal table type, which saves meta-tables directly in ClassesMetas[cls].
    -- The userdata type, on the other hand, gets its own meta-table and then retrofites this meta-table.
    -- The retrofited meta-table is saved in ClassesMetas[meta] and __index and __newindex are unique logic,
    -- other meta-methods are overridden.

    -- Ensure that userdata itself has a meta-table.
    local meta = getmetatable(obj);
    local found = ClassesMetas[meta];
    if found then
        -- It has been Retrofited,skip it.
        return;
    end

    local cls = ObjectsCls[obj];
    local clsMeta = setmetatable(ClassesMetas[cls],{
        __newindex = function (sender,key,value)
            -- Copy the operation on clsMeta to meta.
            rawset(sender,key,value);
            rawset(meta,key,value);
        end
    });
    for k,v in pairs(clsMeta) do
        rawset(meta,k,v);
    end


    local index = rawget(meta,"__index");
    local newIndex = rawget(meta,"__newindex");
    rawset(meta,"__index",function(sender,key)
        local ret = GetAndCheck(cls,key,sender);
        if nil ~= ret then
            return ret;
        end
        -- Finally, check the original method.
        return index(sender,key);
    end);
    rawset(meta,"__newindex",function (sender,key,value)
        local property = ClassesWritable[cls][key];
        if property then
            property(sender,value);
            return;
        else
            if ClassesReadable[cls][key] then
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

    ClassesMetas[meta] = meta;
end

local function ClassGet(self,key)
    if key == Handlers then
        return ClassesHandlers[self];
    end
    if BitsMap[key] then
        return Router:Begin(self,key);
    end
    -- Check the properties first.
    local property = ClassesReadable[self][key];
    if property then
        return property(self);
    else
        if ClassesWritable[self][key] then
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
    local ret = ClassesAll[self][key];
    if nil ~= ret then
        return ret;
    end
    for _, base in ipairs(ClassesBases[self]) do
        ret = CascadeGet(base,key);
        if nil ~= ret then
            return ret;
        end
    end
    -- If not found, look for the c++ class.
    local cppBase = ClassesCppBase[self];
    if nil ~= cppBase then
        return cppBase[key];
    end
end

local rwTable = {r = ClassesReadable,w = ClassesWritable};
local function ClassSet(cls,key,value)
    -- The reserved words cannot be used.
    if ReservedWord[key] or key == Handlers then
        error(("%s is a reserved word and you can't use it."):format(key));
    end

    if key == Properties then
        value = value(cls);
        -- Register properties.
        for rw,t in pairs(rwTable) do
            local subT = value[rw];
            if subT then
                local dst = t[cls];
                for k,v in pairs(subT) do
                    dst[k] = FunctionWrapper(AccessStack,cls,v);
                end
            end
        end
        return;
    end

    local isFunction = "function" == type(value);
    if key == Singleton then
        assert(isFunction,("%s reserved word must be assigned to a function."):format(Singleton));
        -- Register "Instance" automatically.
        ClassesReadable[cls][Instance] = FunctionWrapper(AccessStack,cls,function()
            return GetSingleton(cls,value);
        end);
        ClassesWritable[cls][Instance] = FunctionWrapper(AccessStack,cls,function(_,val)
            DestroySingleton(cls,val)
        end);
        -- Once register "Singleton" for a class,set permission of "new","delete" method to protected.
        local pms = ClassesPermisssions[cls];
        local pm = pms[new];
        if bits.band(pm,Permission.Private) == 0 then
            pms[new] = Permission.Static + Permission.Protected;
        end
        pms[delete] = Permission.Protected;
        return;
    elseif key == Friends then
        assert(isFunction,("%s reserved word must be assigned to a function."):format(Friends));
        local friends = {};
        ClassesFriends[cls] = friends;
        value = FunctionWrapper(AccessStack,cls,value);
        for _, friend in ipairs({value(cls)}) do
            friends[friend] = true;
        end
        return;
    else
        local property = ClassesWritable[cls][key];
        if property then
            property(cls,value);
            return;
        else
            if ClassesWritable[cls][key] then
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
        if not CheckPermission(cls,key,false,true) then
            return;
        end
        local all = ClassesAll[cls];
        local exist = all[key];
        if not exist then
            if not isFunction then
                ClassesMembers[cls][key] = value;
            end
            ClassesPermisssions[cls][key] = Permission.Public;
        end
        if isFunction then
            -- Wrap this function to include control of access permission.
            value = FunctionWrapper(AccessStack,cls,value);
        end
        all[key] = value;
    end
    local meta = MetaMapName[key];
    if meta then
        local metas = ClassesMetas[cls];
        metas[meta] = value;
    end
end

Functions.MakeTableObjectMeta = MakeTableObjectMeta;
Functions.RetrofitMeta = RetrofitMeta;
Functions.ClassSet = ClassSet;
Functions.ClassGet = ClassGet;

local function MakeClassHandlersTable(cls,handlers)
    return setmetatable(handlers,{
        __newindex = function(t,key,value)
            assert(
                "string" == type(key) and key:find(On) == 1,
                ("The name of handler function must start with \"%s\"."):format(On)
            );
            assert("function" == type(value),"Event handler must be a function.");
            -- Ensure that event response functions have access to member variables.
            rawset(t,key,FunctionWrapper(AccessStack,cls,value));
        end
    });
end

function Functions.CreateClassTables()
    local cls,bases,handlers,members,metas = CreateClassTables();

    MakeClassHandlersTable(cls,handlers);
    ClassesAll[cls] = {};
    ClassesPermisssions[cls] = {};

    return cls,bases,handlers,members,metas;
end

function Functions.CheckClassName(cls,args)
    local name = CheckClassName(cls,args);
    if name then
        -- Duplicative class name.
        error(("You cannot use this name \"%s\", which is already used by other class.").format(name));
    end
    return name;
end

function Functions.ClassInherite(cls,args,bases,handlers,members,metas)
    for idx, base in ipairs(args) do
        local baseType = type(base);
        assert(
            baseType == "table"
            or baseType == "function"
            or baseType == "string",
            "Unavailable base class type."
        );
        if "string" == baseType then
            assert(AllClasses[base],("Inherits a class that does not exist.[\"%s\"]").format(base));
            -- Find the base.
            base = AllClasses[base];
        elseif baseType == "function" then
            -- One "Create" function only.
            assert(ClassesCreate[cls] == nil,"Class with more than one creating function.");
            -- Wrapper function generator with an indication that the current class is 0.
            -- 0 represents a special option, meaning that the function generator can access protected members at will.
            ClassesCreate[cls] = FunctionWrapper(AccessStack,0,base);
            -- ClassesCtorIndex[cls] indicates where the function constructor is located,
            -- and adds the class to this when first constructed.
            ClassesCtorIndex[cls] = idx;
        else
            local constructor = IsCppClass and IsCppClass(base);
            if constructor then
                -- It is a c++ class.
                assert(ClassesCreate[cls] == nil,"Class with more than one creating function or native class.");
                local bCtor = base[constructor];
                if bCtor then
                    ClassesCreate[cls] = bCtor;
                end
                ClassesCppBase[cls] = base;
            else
                local create = ClassesCreate[base];
                if create then
                    assert(ClassesCreate[cls] == nil,"Class with more than one creating function.");
                    -- When having the mapping value ClassesCtorIndex[base],
                    -- which indicates that the base class uses the function constructor
                    -- Assign Create to base.new to be called recursively
                    -- in order to return the class to which the function constructor produces the object.
                    ClassesCreate[cls] = ClassesCtorIndex[base] and base[new] or create;
                end

                PushBase(bases,base,handlers,members,metas);
            end
        end
    end
end

function Functions.DestroySingleton(cls,val)
    assert(nil == val,"The nil value needs to be passed in to destory the object.");
    DestroySingleton(cls,val);
end

function Functions.CreateClassObject(...)
    local obj,all = CreateClassObject(...);
    if (nil ~= obj) and (obj == all) then
        all = {};
        ObjectsAll[obj] = all;
    end
    return obj,all;
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
local function CascadeDelete(obj,cls,called)
    if called[cls] then
        return;
    end
    local cppCls = IsCppClass and IsCppClass(cls);
    local del = nil;
    if cppCls then
        del = cls[__del__];
    else
        for _,base in ipairs(ClassesBases[cls]) do
            CascadeDelete(obj,base);
        end

        local pm = ClassesPermisssions[cls][__del__];
        if pm then
            local aCls = AccessStack[#AccessStack];
            if not (aCls == 0 and bits.band(pm,Permission.Protected) ~= 0) then
                local friends = ClassesFriends[cls];
                if (not friends or (not friends[aCls] and not friends[AllClasses[cls]])) and
                (bits.band(pm,Permission.Public) == 0) and
                (aCls ~= cls) and
                (bits.band(pm,Permission.Private) ~= 0)then
                    error(("Attempt to access private members outside the permission. - %s"):format(__del__));
                end
            end
        end

        del = ClassesAll[cls][__del__];
    end
    if del then
        del(obj);
    end
    called[cls] = true;
end

local DefaultDelete = function(self)
    CascadeDelete(self,self[is](),{});
    setmetatable(self,nil);
    ObjectsAll[self] = nil;
    self[DeathMarker] = true;
end

function Functions.FinishTableObject(obj,cls)
    -- Instances of the table type do not require the last cls information
    -- (which is already included in the metatable and in the upvalue).
    ObjectsCls[obj] = nil;
    setmetatable(obj,MakeTableObjectMeta(cls));

    -- If the object is a table,
    -- provide a delete method to the object by default.

    -- If the object is a userdata,
    -- you should provide a delete method with c++.

    -- Since you cannot explicitly determine the return type of the function constructor,
    -- register the delete function when you know explicitly that it is not returning userdata after constructing it once.
    if nil == ClassesAll[cls][delete] then
        ClassesAll[cls][delete] = FunctionWrapper(AccessStack,cls,DefaultDelete);
        local pm = ClassesPermisssions[cls][__del__] or Permission.Public;
        if ClassesReadable[cls][Instance] and bits.band(pm,Permission.Private) == 0 then
            -- If there is a singleton, at least the protected permission for delete will be guaranteed.
            ClassesPermisssions[cls][delete] = Permission.Protected;
        else
            -- Otherwise delete has the same access premission as __del__.
            ClassesPermisssions[cls][delete] = pm;
        end
    end
end

function Functions.AttachClassFunctions(cls,_is,_new)
    ClassesAll[cls][is] = _is;
    ClassesPermisssions[cls][is] = Permission.Public;
    if nil ~= _new then
        -- In debug mode,the "new" method is public and static.
        ClassesAll[cls][new] = FunctionWrapper(AccessStack,cls,_new);
        -- Use + instead of | to try to keep lua 5.3 or lower compatible.
        ClassesPermisssions[cls][new] = Permission.Public + Permission.Static;
    end
end

return Functions;