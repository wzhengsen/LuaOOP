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

local setmetatable = setmetatable;
local rawset = rawset;
local pairs = pairs;
local ipairs = ipairs;
local type = type;
local select = select;

local Config = require("OOP.Config");
local Internal = require("OOP.Variant.Internal");
local class = require("OOP.BaseClass");

local E_Handlers = require("OOP.Event").Handlers;
local R = require("OOP.Router");
local Router = R.Router;
local BitsMap = R.BitsMap;

local On = Config.On;
local delete = Config.delete;
local DeathMarker = Config.DeathMarker;
local __del__ = Config.__del__;
local IsCppClass = Config.CppClass.IsCppClass;
local IsInherite = Config.CppClass.IsInherite;

local new = Config.new;
local is = Config.is;

local Properties = Config.Properties;
local Singleton = Config.Singleton;
local Instance = Config.Instance;
local Handlers = Config.Handlers;
local Friends = Config.Friends;

local MetaMapName = Config.MetaMapName;

local _IsNull = class.IsNull;

-- functions.
local Functions = Internal;
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
local ClassesSingleton = Functions.ClassesSingleton;
local ObjectsAll = Functions.ObjectsAll;
local ObjectsCls = Functions.ObjectsCls;

---Copy any value.
---
---@param any any
---@return any
---
local function Copy(any,existTab)
    if type(any) ~= "table" then
        return any;
    end
    if existTab then
        local ret = existTab[any];
        if nil ~= ret then
            return ret;
        end
    end

    existTab = existTab or {};
    local tempTab = {};
    existTab[any] = tempTab;
    for k,v in pairs(any) do
        tempTab[Copy(k,existTab)] = Copy(v,existTab);
    end
    return tempTab;
end

---Get the single instance, where it is automatically judged empty
---and does not require the user to care.
---
---@param self any
---@param call function
---
local function GetSingleton(self,call)
    local s = ClassesSingleton[self];
    if _IsNull(s) then
        s = call(self);
        ClassesSingleton[self] = s;
    end
    return s;
end

---Destroy the single instance.
---It is mapped to Instance property.
---
---@param self table
---@param val nil   This parameter must be a nil value.
---
local function DestroySingleton(self,val)
    if nil == val then
        local s = ClassesSingleton[self];
        if not _IsNull(s) then
            s:delete();
            ClassesSingleton[self] = nil;
        end
    end
end

---register meta-table of properties for class.
---
---@param cls table
---@param bases table
---@param rw table Readable or writable.
---@return table,table
---
local function CreateClassPropertiesTable(cls,bases,rw)
    if rw then
        return setmetatable({},{
            __index = function (_,key)
                for _,base in ipairs(bases) do
                    local ret = rw[base];
                    if nil ~= ret then
                        ret = ret[key];
                        if nil ~= ret then
                            return ret;
                        end
                    end
                end
            end
        });
    end
    return CreateClassPropertiesTable(cls,bases,ClassesReadable),CreateClassPropertiesTable(cls,bases,ClassesWritable);
end


---Check the class name.
---If there is a duplicate class name, return that name, otherwise return nil
---
---@param cls table
---@param args table
---@return string?
---
local function CheckClassName(cls,args)
    if type(args[1]) == "string" then
        local name = table.remove(args,1);
        if nil == AllClasses[name] then
            AllClasses[name] = cls;
            AllClasses[cls] = name;
        else
            return name;
        end
    end
    return nil;
end

local function PushBase(bases,base,handlers,members,metas,idx)
    -- Inherite handlers/members/metas from base.
    local found = ClassesHandlers[base];
    if found then
        for handler,func in pairs(found) do
            handlers[handler] = func;
        end
    end
    found = ClassesMembers[base];
    if found then
        for key,member in pairs(found) do
            members[key] = member;
        end
    end
    found = ClassesMetas[base];
    if found then
        for key,meta in pairs(found) do
            metas[key] = meta;
        end
    end
    if idx then
        table.insert(bases,idx,base);
    else
        table.insert(bases,base);
    end
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
        local _is = base[is];
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

local function CreateClassIs(cls,base)
    return function (...)
        return ClassIs(cls,base,...);
    end;
end

---Creates an object of a class that will be created using the create function if it exists,
---otherwise a table is created.
---Returns the object created and the table holding the members of that object.
---
---@param cls table
---@param create function|nil
---@param handlers table
---@param members table
---@param metas table
---@return "table?|userdata?"
---@return "table?"
local function CreateClassObject(cls,create,handlers,members,metas,...)
    --[[
        Here, the case of multiple function constructions needs to be considered, e.g.

        local C1 = class();
        local C2 = class(function()return C1.new();end);
        local C3 = class(C2);
        local C4 = class(function()return C3.new();end);

        In this inheritance relationship,
        since the base classes of C4 and C2 are not explicitly specified,
        you cannot directly query by ClassesBases field,
        you need to get the returned base class type and add it to ClassesBases.


        Since a function constructor is designed to return the same type,
        do not use the following inheritance.

        local E1 = class();
        local E2 = class();
        local E3 = class(function(case)
            if case == 1 then
                reutrn E1.new();
            else
                return E2.new();
            end
        );
    ]]
    local obj = nil;
    local all = nil;
    if create then
        obj = create(...);
        if nil ~= obj then
            local ctorIdx = ClassesCtorIndex[cls];
            if ctorIdx then
                local preCls = ObjectsCls[obj];
                if preCls then
                    PushBase(ClassesBases[cls],preCls,handlers,members,metas,ctorIdx);
                end
                -- After creating the object of class ,
                -- ClassesCtorIndex[cls] can no longer be used.
                ClassesCtorIndex[cls] = nil;
            end
        end
    else
        obj = {};
    end
    if nil ~= obj then
        if "table" == type(obj) then
            all = obj;
        else
            all = {};
            ObjectsAll[obj] = all;
        end
    end
    return obj,all;
end

---Cascade to get the value of the corresponding key of a class and its base class
---(ignoring metamethods).
---
---@param cls table
---@param key any
---@return any
---
local function CascadeGet(cls,key)
    local ret = rawget(cls,key);
    if nil ~= ret then
        return ret;
    end
    local bases = ClassesBases[cls];
    if bases then
        for _,base in ipairs(bases) do
            ret = CascadeGet(base,key);
            if nil ~= ret then
                return ret;
            end
        end
    end
end

---Generate a meta-table for an object (typically a table) generated by a pure lua class.
---
---@param cls table
---@return table
---
local function MakeTableObjectMeta(cls)
    local meta = ClassesMetas[cls];
    if nil == rawget(meta,"__index") then
        meta.__index = function (sender,key)
            -- Check the key of current class first.
            local ret = rawget(cls,key);
            if nil ~= ret then
                return ret;
            end
            -- Check the properties of current class.
            local property = ClassesReadable[cls][key];
            if property then
                return property(sender);
            end
            -- Check base class.
            for _, base in ipairs(ClassesBases[cls]) do
                ret = CascadeGet(base,key);
                if nil ~= ret then
                    return ret;
                end
            end
        end;
        meta.__newindex = function (sender,key,value)
            local property = ClassesWritable[cls][key];
            if property then
                property(sender,value);
                return;
            end
            rawset(sender,key,value);
        end;
    end
    return meta;
end


--- Generate a meta-table for an object (typically a userdata).
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
    rawset(meta,"__index",function (sender,key)
        -- Check self all.
        local all = ObjectsAll[sender];
        local ret = all[key];
        if nil ~= ret then
            return ret;
        end

        -- Check cls methods and members.
        ret = rawget(cls,key);
        if nil ~= ret then
            return ret;
        end

        -- Check cls properties.
        local property = ClassesReadable[cls][key];
        if property then
            return property(sender);
        end
        -- Check cls bases.
        for _, base in ipairs(ClassesBases[cls]) do
            ret = CascadeGet(base,key);
            if nil ~= ret then
                return ret;
            end
        end
        -- Finally, check the original method.
        return index and index(sender,key) or nil;
    end);
    local newIndex = rawget(meta,"__newindex");
    rawset(meta,"__newindex",function (sender,key,value)
        local property = ClassesWritable[cls][key];
        if property then
            property(sender,value);
            return;
        end
        local all = ObjectsAll[sender];
        all[key] = value;

        if newIndex then
            -- Finally, write by the original method.
            newIndex(sender,key,value);
        end
    end);

    ClassesMetas[meta] = meta;
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
        for _,base in ipairs(ClassesBases[cls]) do
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

local OnLen = #On + 1;
local function RegisterHandlersAndMembers(obj,all,handlers,members)
    for key,func in pairs(handlers) do
        -- Automatically listens to events.
        E_Handlers.On(key:sub(OnLen),obj,func);
    end
    for key,mem in pairs(members) do
        -- Automatically set member of object.
        -- Before the instance can change the meta-table, its members must be set.
        all[key] = Copy(mem);
    end
end

---Register meta-tables for objects of type table that have been generated.
---
---@param obj table
---@param cls table
---
local function FinishTableObject(obj,cls)
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
    if nil == rawget(cls,delete) then
        rawset(cls,delete,DefaultDelete);
    end
end

local function FinishUserDataObject(obj,cls)
    -- Instances of the userdata type require the last cls information.
    -- Because multiple different lua classes can inherit from the same c++ class.
    ObjectsCls[obj] = cls;
    RetrofiteUserDataObjectMeta(obj);
end

---Create a class table with base info.
---
---@return table cls
---@return table bases
---@return table handlers
---@return table members
---@return table metas
---
local function CreateClassTables()
    local cls = {};
    local bases = {};
    local handlers = {};
    local members = {};
    local metas = {};

    ClassesBases[cls] = bases;

    ClassesHandlers[cls] = handlers;

    local r,w = CreateClassPropertiesTable(cls,bases);
    ClassesReadable[cls] = r;
    ClassesWritable[cls] = w;

    ClassesMembers[cls] = members;
    ClassesMetas[cls] = metas;

    return cls,bases,handlers,members,metas;
end

local function AttachClassFunctions(cls,_is,_new)
    cls[is] = _is;
    cls[new] = _new;
end

local function ClassInherite(cls,args,bases,handlers,members,metas)
    for idx, base in ipairs(args) do
        local baseType = type(base);
        if "string" == baseType then
            -- Find the base.
            base = AllClasses[base];
        elseif baseType == "function" then
            ClassesCreate[cls] = base;
            -- ClassesCtorIndex[cls] indicates where the function constructor is located,
            -- and adds the class to this when first constructed.
            ClassesCtorIndex[cls] = idx;
        else
            local constructor = IsCppClass and IsCppClass(base);
            if constructor then
                -- It is a c++ class.
                local bCtor = base[constructor];
                if bCtor then
                    ClassesCreate[cls] = bCtor;
                end
                ClassesCppBase[cls] = base;
            else
                local create = ClassesCreate[base];
                if create then
                    -- When having the value ClassesCtorIndex[cls],
                    -- which indicates that the base class uses the function constructor
                    -- Assign "create" to base.new to be called recursively
                    -- in order to return the class to which the function constructor produces the object.
                    ClassesCreate[cls] = ClassesCtorIndex[base] and base[new] or create;
                end

                PushBase(bases,base,handlers,members,metas);
            end
        end
    end
end

---In non-debug mode, no access modifiers are considered.
---
---@param cls table
---@param key any
---@return any
---
local function ClassGet(cls,key)
    if BitsMap[key] then
        return Router:Begin(cls,key);
    end
    if key == Handlers then
        return ClassesHandlers[cls];
    end
    -- Check the properties first.
    local property = ClassesReadable[cls][key];
    if property then
        return property(cls);
    end
    for _, base in ipairs(ClassesBases[cls]) do
        local ret = CascadeGet(base,key);
        if nil ~= ret then
            return ret;
        end
    end
    -- If not found, look for the c++ class.
    local cppBase = ClassesCppBase[cls];
    if nil ~= cppBase then
        return cppBase[key];
    end
end

local rwTable = {r = ClassesReadable,w = ClassesWritable};
local function ClassSet(cls,key,value)
    if key == Properties then
        -- It must be a function.
        -- Call it automatically.
        value = value(cls);
        -- Register properties.
        for rw,t in pairs(rwTable) do
            local sub = value[rw];
            if sub then
                local dst = t[cls];
                for k,v in pairs(sub) do
                    dst[k] = v;
                end
            end
        end
        return;
    elseif key == Singleton then
        -- Register "Instance" automatically.
        ClassesReadable[cls][Instance] = function ()
            return GetSingleton(cls,value);
        end;
        ClassesWritable[cls][Instance] = function (_,val)
            DestroySingleton(cls,val)
        end;
        return;
    elseif key == Handlers then
        return;
    elseif key == Friends then
        value(cls);
        return;
    else
        local property = ClassesWritable[cls][key];
        if property then
            property(cls,value);
            return;
        end
        local exist = rawget(cls,key);
        if not exist and "function" ~= type(value) then
            ClassesMembers[cls][key] = value;
        end
        rawset(cls,key,value);
    end
    local meta = MetaMapName[key];
    if meta then
        ClassesMetas[cls][meta] = value;
    end
end

Functions.class = class;
Functions.GetSingleton = GetSingleton;
Functions.DestroySingleton = DestroySingleton;
Functions.IsNull = _IsNull;
Functions.Copy = Copy;
Functions.CheckClassName = CheckClassName;
Functions.PushBase = PushBase;
Functions.CreateClassIs = CreateClassIs;
Functions.CreateClassObject = CreateClassObject;
Functions.RegisterHandlersAndMembers = RegisterHandlersAndMembers;
Functions.FinishTableObject = FinishTableObject;
Functions.FinishUserDataObject = FinishUserDataObject;
Functions.CreateClassTables = CreateClassTables;
Functions.AttachClassFunctions = AttachClassFunctions;
Functions.ClassInherite = ClassInherite;
Functions.ClassGet = ClassGet;
Functions.ClassSet = ClassSet;

return Functions;