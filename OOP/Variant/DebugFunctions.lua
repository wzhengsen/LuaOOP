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
local ctor = Config.ctor;
local dtor = Config.dtor;
local __new__ = Config.__new__;
local __delete__ = Config.__delete__;

local friends = Config.friends;
local __singleton__ = Config.__singleton__;
local Instance = Config.Instance;
local handlers = Config.handlers;
local set = Config.set;
local get = Config.get;

local DeathMarker = Config.DeathMarker;

local MetaMapName = Config.MetaMapName;

local PropertyBehavior = Config.PropertyBehavior;
local ConstBehavior = Config.ConstBehavior;

local Functions = require("OOP.Variant.BaseFunctions");
local GetSingleton = Functions.GetSingleton;
local DestroySingleton = Functions.DestroySingleton;
local ClassInherite = Functions.ClassInherite;
local CreateClassObject = Functions.CreateClassObject;
local AllClasses = Functions.AllClasses;
local ClassesReadable = Functions.ClassesReadable;
local ClassesWritable = Functions.ClassesWritable;
local ClassesHandlers = Functions.ClassesHandlers;
local ClassesBases = Functions.ClassesBases;
local ClassesMembers = Functions.ClassesMembers;
local ClassesMetas = Functions.ClassesMetas;
local ClassesBanNew = Functions.ClassesBanNew;
local ClassesBanDelete = Functions.ClassesBanDelete;
local ClassesNew = Functions.ClassesNew;
local ClassesDelete = Functions.ClassesDelete;
local ObjectsAll = Functions.ObjectsAll;
local ObjectsCls = Functions.ObjectsCls;
local CheckClassName = Functions.CheckClassName;
local CreateClassTables = Functions.CreateClassTables;

local ClassesAll = Functions.ClassesAll;
local ClassesPermisssions = Functions.ClassesPermisssions;
local ClassesFriends = Functions.ClassesFriends;
local AccessStack = Functions.AccessStack;

local ReservedWord = Functions.ReservedWord;

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

    if byObj and bits.band(pm,Permission.static) ~= 0 then
        error(("Objects cannot access static members of a class. - %s"):format(key));
    end
    if set then
        if bits.band(pm,Permission.const) ~= 0 then
            -- Check const.
            if ConstBehavior ~= 2 then
                if ConstBehavior == 0 then
                    if Version > 5.4 then
                        warn(("You cannot modify the const value. - %s"):format(key));
                    end
                elseif ConstBehavior == 1 then
                    error(("You cannot modify the const value. - %s"):format(key));
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

    local stackCls = AccessStack[#AccessStack];
    local _friends = ClassesFriends[cls];
    --Check if it is a friendly class.
    if not _friends or (not _friends[stackCls] and not _friends[AllClasses[stackCls]]) then
        if bits.band(pm,Permission.public) == 0 then
            -- Check public,private,protected.
            if stackCls ~= cls then
                if bits.band(pm,Permission.private) ~= 0 then
                    error(("Attempt to access private members outside the permission. - %s"):format(key));
                elseif bits.band(pm,Permission.protected) ~= 0 and (not stackCls or not stackCls.is(cls)) then
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
---@param cls table
---@param key any
---@param called table
---@return any
---
local function CascadeGet(cls,key,called)
    if called[cls] then
        return nil;
    end
    called[cls] = true;
    local all = ClassesAll[cls];
    if nil ~= all then
        local ret = all[key];
        if nil ~= ret then
            return ret;
        end
        local bases = ClassesBases[cls];
        if bases then
            for _,base in ipairs(bases) do
                ret = CascadeGet(base,key,called);
                if nil ~= ret then
                    return ret;
                end
            end
        end
    else
        return cls[key];
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
        ret = CascadeGet(base,key,{});
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
local function RetrofiteUserDataObjectMeta(obj)
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
    local indexFunc = "function" == type(index);
    local newIndexFunc =  "function" == type(newIndex);
    rawset(meta,"__index",function(sender,key)
        local cls = ObjectsCls[sender];
        if cls then
            local ret = GetAndCheck(cls,key,sender);
            if nil ~= ret then
                return ret;
            end
        end
        -- Finally, check the original method or table.
        if index then
            return indexFunc and index(sender,key) or index[key];
        end
    end);
    rawset(meta,"__newindex",function (sender,key,value)
        local cls = ObjectsCls[sender];
        if cls then
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
            local all = ObjectsAll[sender];
            all[key] = value;
        end
        -- Finally, write by the original method.
        if not cls or newIndex then
            if newIndexFunc then
                newIndex(sender,key,value);
            elseif newIndex then
                newIndex[key] = value;
            else
                error(("attempt to index a %s value."):format(meta.__name or ""));
            end
        end
    end);

    ClassesMetas[meta] = meta;
end

local function FinishUserDataObject(obj,cls)
    -- Instances of the userdata type require the last cls information.
    -- Because multiple different lua classes can inherit from the same c++ class.
    ObjectsCls[obj] = cls;
    RetrofiteUserDataObjectMeta(obj);
end

local function ClassGet(cls,key)
    if BitsMap[key] then
        return Router:Begin(cls,key);
    end
    if key == handlers then
        return ClassesHandlers[cls];
    elseif key == get then
        return ClassesReadable[cls];
    elseif key == set then
        return ClassesWritable[cls];
    end
    -- Check the properties first.
    local property = ClassesReadable[cls][key];
    if property then
        return property(cls);
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
    if not CheckPermission(cls,key,false) then
        return;
    end
    local ret = ClassesAll[cls][key];
    if nil ~= ret then
        return ret;
    end
    for _, base in ipairs(ClassesBases[cls]) do
        ret = CascadeGet(base,key,{});
        if nil ~= ret then
            return ret;
        end
    end
end

local function ClassSet(cls,key,value)
    -- The reserved words cannot be used.
    if ReservedWord[key] then
        error(("%s is a reserved word and you can't set it."):format(key));
    end

    if key == friends then
        assert("table" == type(value),("%s reserved word must be assigned to a table."):format(friends));
        local fri = {};
        ClassesFriends[cls] = fri;
        for _,v in ipairs(value) do
            fri[v] = true;
        end
        return;
    end

    local isFunction = "function" == type(value);
    if key == __singleton__ then
        assert(isFunction,("%s reserved word must be assigned to a function."):format(__singleton__));
        -- Register "Instance" automatically.
        ClassesReadable[cls][Instance] = FunctionWrapper(AccessStack,cls,function()
            return GetSingleton(cls,value);
        end);
        ClassesWritable[cls][Instance] = FunctionWrapper(AccessStack,cls,function(_,val)
            DestroySingleton(cls,val)
        end);
        -- Once register "__singleton__" for a class,set permission of "new","delete" method to protected.
        local pms = ClassesPermisssions[cls];
        local pm = pms[new];
        if bits.band(pm,Permission.private) == 0 then
            pms[new] = Permission.static + Permission.protected;
        end
        pms[delete] = Permission.protected;
        return;
    elseif key == __new__ then
        assert(isFunction,("%s reserved word must be assigned to a function."):format(key));
        ClassesNew[cls] = FunctionWrapper(AccessStack,cls,value);
        return;
    elseif key == __delete__ then
        assert(isFunction,("%s reserved word must be assigned to a function."):format(key));
        ClassesDelete[cls] = FunctionWrapper(AccessStack,cls,value);
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
            ClassesPermisssions[cls][key] = Permission.public;
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
Functions.FinishUserDataObject = FinishUserDataObject;
Functions.ClassSet = ClassSet;
Functions.ClassGet = ClassGet;

local function MakeClassHandlersTable(cls,handlers)
    return setmetatable(handlers,{
        __newindex = function(t,key,value)
            assert(
                "string" == type(key) and key:find(On) == 1,
                ("The name of handler function must start with \"%s\"."):format(On)
            );
            assert("function" == type(value),"event handler must be a function.");
            -- Ensure that event response functions have access to member variables.
            rawset(t,key,FunctionWrapper(AccessStack,cls,value));
        end
    });
end

local function MakeClassGetSetTable(cls,...)
    for _,v in ipairs({...}) do
        local meta = getmetatable(v);
        meta.__newindex = function(t,key,value)
            rawset(t,key,FunctionWrapper(AccessStack,cls,value));
        end;
    end
end

function Functions.CreateClassTables()
    local cls,all,bases,handlers,members,metas,r,w = CreateClassTables();

    MakeClassHandlersTable(cls,handlers);
    MakeClassGetSetTable(cls,r,w);
    all = {}
    ClassesAll[cls] = all;
    ClassesPermisssions[cls] = {};

    return cls,all,bases,handlers,members,metas;
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
            or baseType == "string",
            "Unavailable base class type."
        );
        if "string" == baseType then
            assert(AllClasses[base],("Inherits a class that does not exist.[\"%s\"]").format(base));
        end
        for i,b in ipairs(args) do
            if b == base and idx ~= i then
                error("It is not possible to inherit from the same class repeatedly.");
            end
        end
        local pms = ClassesPermisssions[base];
        if ClassesBanNew[base] then
            ClassesBanNew[cls] = true;
        elseif pms then
            local pm = pms[ctor];
            if pm and bits.band(pm,Permission.private) ~= 0 then
                ClassesBanNew[cls] = true;
            end
        end

        if ClassesBanDelete[base] then
            ClassesBanDelete[cls] = true;
        elseif pms then
            local pm = pms[dtor];
            if pm and bits.band(pm,Permission.private) ~= 0 then
                ClassesBanDelete[cls] = true;
            end
        end
    end
    ClassInherite(cls,args,bases,handlers,members,metas);
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
    Cascade calls to dtor.
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
    local bases = ClassesBases[cls];
    if bases then
        for _,base in ipairs(bases) do
            CascadeDelete(obj,base,called);
        end
    end

    local pm = ClassesPermisssions[cls][dtor];
    if pm then
        local aCls = AccessStack[#AccessStack];
        local _friends = ClassesFriends[cls];
        if (not _friends or (not _friends[aCls] and not _friends[AllClasses[cls]])) and
        (bits.band(pm,Permission.public) == 0) and
        (aCls ~= cls) and
        (bits.band(pm,Permission.private) ~= 0)then
            error(("Attempt to access private members outside the permission. - %s"):format(dtor));
        end
    end

    -- Since the meta method is not triggered here,
    -- it is necessary to determine the permission in advance.
    local del = ClassesAll[cls][dtor];
    if del then
        del(obj);
    end
    called[cls] = true;
end

function Functions.CallDel(self)
    CascadeDelete(self,self[is](),{});
    ObjectsAll[self] = nil;
end

function Functions.CreateClassDelete(cls)
    return function (self)
        local d = ClassesDelete[cls];
        if d then
            d(self);
        else
            CascadeDelete(self,cls,{});
            setmetatable(self,nil);
            self[DeathMarker] = true;
        end
        ObjectsAll[self] = nil;
    end
end

function Functions.AttachClassFunctions(cls,_is,_new,_delete)
    local all = ClassesAll[cls];
    local pms = ClassesPermisssions[cls];
    all[is] = _is;
    pms[is] = Permission.public;
    -- In debug mode,the "new" method is public and static.
    all[new] = FunctionWrapper(AccessStack,cls,_new);
    -- Use + instead of | to try to keep lua 5.3 or lower compatible.
    pms[new] = Permission.public + Permission.static;

    all[delete] = FunctionWrapper(AccessStack,cls,_delete);
    pms[delete] = Permission.public;
end

return Functions;