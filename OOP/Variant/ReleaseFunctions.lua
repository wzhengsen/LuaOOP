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
local setmetatable = setmetatable;
local rawset = rawset;
local rawget = rawget;
local pairs = pairs;
local ipairs = ipairs;
local type = type;
local select = select;
local remove = table.remove;
local insert = table.insert;
local d_setmetatable = debug.setmetatable;
local next = next;

local Config = require("OOP.Config");
local i18n = require("OOP.i18n");
local Internal = require("OOP.Variant.Internal");
local class = require("OOP.BaseClass");
local BaseFunctions = require("OOP.BaseFunctions");

local Copy = BaseFunctions.Copy;
local Update2Children = BaseFunctions.Update2Children;
local Update2ChildrenWithKey = BaseFunctions.Update2ChildrenWithKey;
local ClassBasesIsRecursive = BaseFunctions.ClassBasesIsRecursive;


local E_Handlers = require("OOP.Event").handlers;
local R = require("OOP.Router");
local Router = R.Router;
local BitsMap = R.BitsMap;
local Begin = R.Begin;

local delete = Config.delete;
local dtor = Config.dtor;

local new = Config.new;
local is = Config.is;

local __internal__ = Config.__internal__;
local __singleton = Config.__singleton;
local Instance = Config.Instance;
local handlers = Config.handlers;
local friends = Config.friends;
local __new = Config.__new;
local __delete = Config.__delete;
local Meta = Config.Meta;
local static = Config.Qualifiers.static;
local get = Config.get;
local set = Config.set;
local __cls__ = Config.__cls__;

local MetaMapName = Config.MetaMapName;

local null = class.null;

local Functions = Internal;
local ClassesChildrenByName = Functions.ClassesChildrenByName;
local NamedClasses = Functions.NamedClasses;
local AllClasses = Functions.AllClasses;
local AllEnumerations = Functions.AllEnumerations;
local ClassesReadable = Functions.ClassesReadable;
local ClassesWritable = Functions.ClassesWritable;
local ClassesHandlers = Functions.ClassesHandlers;
local ClassesBases = Functions.ClassesBases;
local ClassesChildren = Functions.ClassesChildren;
local ClassesMembers = Functions.ClassesMembers;
local ClassesMetas = Functions.ClassesMetas;
local ClassesNew = Functions.ClassesNew;
local ClassesDelete = Functions.ClassesDelete;
local ClassesSingleton = Functions.ClassesSingleton;
local ClassesStatic = Functions.ClassesStatic;
local AllObjects = Functions.AllObjects;
local ObjectsCls = Functions.ObjectsCls;
local DeathMark = Functions.DeathMark;

local ClearMembersInRelease = Config.ClearMembersInRelease;

---Get the single instance, where it is automatically judged empty
---and does not require the user to care.
---
---@param self any
---@param call function
---
local function GetSingleton(self,call)
    local s = ClassesSingleton[self];
    if null(s) then
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
        if not null(s) then
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


local registry = debug.getregistry();
---
---Check the class and return the meta-table for the class object.
---
---
---@param args table
---@return table @cls
---@return table @metas
---@return string? @name
---
local function CheckClass(args)
    local metas = nil;
    local name = nil;
    local cls = {};
    if type(args[1]) == "string" then
        name = remove(args,1);
        if NamedClasses[name] then
            error((i18n"You cannot use this name \"%s\", which is already used by other class.").format(name));
        else
            -- Save the names and classes mapped to each other.
            NamedClasses[name] = cls;
            NamedClasses[cls] = name;

            metas = registry[name];
            if nil == metas or rawget(metas,__internal__) then
                -- If a meta table by that name does not exist in the registry, it is created.
                -- Otherwise, the class is not an internal class.
                metas = {[__internal__] = true};
                registry[name] = metas;
                ClassesMetas[cls] = metas;
            else
                ClassesMetas[cls] = {[__internal__] = true};
            end
        end
    else
        metas = {[__internal__] = true};
        ClassesMetas[cls] = metas;
    end
    return cls,metas,name;
end

local function PushBase(cls,bases,base,handlers,members,metas)
    -- Inherite handlers/members/metas from base.

    -- To save runtime performance,
    -- some values that may be looked up at runtime are recorded in the table at inheritance time.
    local found = ClassesHandlers[base];
    if found then
        for handler,func in pairs(found) do
            handlers[handler] = func;
        end
    end
    found = ClassesMembers[base];
    if found then
        for key,save in pairs(found) do
            members[key] = save;
        end
    end
    found = ClassesMetas[base];
    if found then
        for key,_ in pairs(Meta) do
            local meta = found[key];
            if nil ~= meta and nil == metas[key] then
                metas[key] = meta;
            end
        end
    end

    local bmt = getmetatable(base);
    if bmt then
        local mt = getmetatable(cls);
        for key,_ in pairs(Meta) do
            local meta = bmt[key];
            if nil == mt[key] and nil ~= meta then
                mt[key] = meta;
            end
        end
    end

    local _new = ClassesNew[base];
    if _new then
        ClassesNew[cls] = _new;
    end
    local _delete = ClassesDelete[base];
    if _delete then
        ClassesDelete[cls] = _delete;
    end
    -- Record the current class into the subclasses table of the base class,
    -- and if there are any member (except for functions, but containing metamethods and events) changes in the base class afterwards,
    -- they will be mapped to all subclasses.

    local children = ClassesChildren[base];
    if children then
        children[#children + 1] = cls;
    end
    bases[#bases + 1] = base;
end

---If there is no parameter,it means the return value is the current type.
---@return table
local function ClassIs(cls,bases,...)
    local len = select("#",...);
    if 0 == len then
        return cls;
    end
    local baseCls = (...);
    if baseCls == nil then
        return false;
    elseif baseCls == cls then
        return true;
    end
    return ClassBasesIsRecursive(baseCls,bases);
end

local function CreateClassIs(cls,bases)
    return function (...)
        return ClassIs(cls,bases,...);
    end;
end

---Creates an object of a class that will be created using the create function if it exists,
---otherwise a table is created.
---Returns the object created and the table holding the members of that object.
---
---@param cls table
---@return "table?|userdata?"
---@return "table?"
local function CreateClassObject(cls,...)
    local _new = ClassesNew[cls];
    local obj = _new and _new(...) or {};
    local all = nil;
    local t = type(obj);
    if "table" == t then
        all = obj;
    elseif nil ~= obj then
        -- Try to get a pre-existing 'all' table (nested constructs may exist).
        all = AllObjects[obj];
        if nil == all then
            all = {};
            AllObjects[obj] = all;
        end
    end
    return obj,all;
end

---Cascade to get the value of the corresponding key of a class and its base class
---(ignoring metamethods).
---
---@param cls table
---@param key any
---@param called table
---@param byObject? boolean
---@return any
---
local function CascadeGet(cls,key,called,byObject)
    if called[cls] then
        return nil;
    end
    called[cls] = true;
    local ret = rawget(cls,key);
    if nil ~= ret then
        return ret;
    end
    if not byObject then
        local static = ClassesStatic[cls];
        if static then
            ret = static[key];
            if nil ~= ret then
                return ret[1];
            end
        end
    end
    local bases = ClassesBases[cls];
    if bases then
        for _,base in ipairs(bases) do
            ret = CascadeGet(base,key,called,byObject);
            if nil ~= ret then
                return ret;
            end
        end
    end
end

local function RegisterHandlersAndMembers(obj,all,handlers,members)
    for key,func in pairs(handlers) do
        -- Automatically listens to events.
        E_Handlers.On(key,obj,func);
    end
    for key,value in pairs(members) do
        -- Automatically set member of object.
        -- Before the instance can change the meta-table, its members must be set.
        rawset(all,key,Copy(value));
    end
end

local HandlersControlObj = nil;
local HandlersControl = setmetatable({},{
    __newindex = function (_,key,value)
        if nil == value then
            -- If value is nil,we remove the response of this event name.
            E_Handlers.Remove(key,HandlersControlObj);
        elseif value == false or value == true then
            -- If value is a boolean,we enable/disable it.
            E_Handlers.Enabled(key,HandlersControlObj,value);
        elseif type(value) == "function" then
            -- If value is a function,we reset the response of this event name.
            E_Handlers.Remove(key,HandlersControlObj);
            E_Handlers.On(key,HandlersControlObj,value);
        else
            -- If value is a number,we sort it.
            E_Handlers.Order(key,HandlersControlObj,math.floor(value));
        end
    end
});

---Generate a meta-table for an internal object.
---
---@param cls table
---@return table
---
local function MakeInternalObjectMeta(cls,metas)
    metas.__index = function (sender,key)
        if key == handlers then
            HandlersControlObj = sender;
            return HandlersControl;
        end
        local ret = nil;
        local all = AllObjects[sender];
        if all then
            ret = all[key];
            if nil ~= ret then
                return ret;
            end
        end

        -- Check the properties of current class.
        local property = ClassesReadable[cls][key];
        if property and not property[2] then
            return property[1](sender);
        end

        -- Check the key of current class.
        ret = rawget(cls,key);
        if nil ~= ret then
            return ret;
        end

        -- Check base class.
        for _, base in ipairs(ClassesBases[cls]) do
            ret = CascadeGet(base, key, {}, true);
            if nil ~= ret then
                return ret;
            end
        end
        return nil;
    end;
    metas.__newindex = function (sender,key,value)
        local property = ClassesWritable[cls][key];
        if property and not property[2] then
            property[1](sender,value);
            return;
        end
        local all = AllObjects[sender];
        if all then
            all[key] = value;
            return;
        end
        rawset(sender,key,value);
    end;
    return metas;
end

local function RetrofiteMetaMethod(_cls, metas, name, forceRetrofit)
    --- Since the meta table may still be used for external classes or other classes after being retrofitted,
    --- the custom meta method goes through the sender to find it.
    local oldMeta = rawget(metas, name);
    if name == "__gc" or name == "__close" then
        rawset(metas,name,function (sender)
            local cls = ObjectsCls[sender];
            if nil == cls and forceRetrofit then
                ObjectsCls[sender] = _cls;
                cls = _cls;
            end
            local meta = cls and ClassesMetas[cls][name] or oldMeta;
            if meta then
                return meta(sender);
            end
        end);
    elseif name == "__eq" then
        rawset(metas,name,function (sender,other)
            local cls = ObjectsCls[sender];
            if nil == cls and forceRetrofit then
                ObjectsCls[sender] = _cls;
                cls = _cls;
            end
            local meta = cls and ClassesMetas[cls][name] or oldMeta;
            if meta then
                return meta(sender,other);
            end
            return rawequal(sender,other);
        end);
    elseif name == "__tostring" then
        rawset(metas,name,function (sender)
            local cls = ObjectsCls[sender];
            if nil == cls and forceRetrofit then
                ObjectsCls[sender] = _cls;
                cls = _cls;
            end
            local meta = cls and ClassesMetas[cls][name] or oldMeta;
            if meta then
                return meta(sender);
            end
            return (rawget(metas,"__name") or type(sender)) .. " - LuaOOP Object.";
        end);
    elseif name == "__len" then
        rawset(metas,name,function (sender)
            local cls = ObjectsCls[sender];
            if nil == cls and forceRetrofit then
                ObjectsCls[sender] = _cls;
                cls = _cls;
            end
            local meta = cls and ClassesMetas[cls][name] or oldMeta;
            if meta then
                return meta(sender);
            end
            return rawlen(sender);
        end);
    elseif name == "__pairs" then
        rawset(metas,name,function (sender)
            local cls = ObjectsCls[sender];
            if nil == cls and forceRetrofit then
                ObjectsCls[sender] = _cls;
                cls = _cls;
            end
            local meta = cls and ClassesMetas[cls][name] or oldMeta;
            if meta then
                return meta(sender);
            end
            return next,sender,nil;
        end);
    else
        rawset(metas,name,function (sender,...)
            local cls = ObjectsCls[sender];
            if nil == cls and forceRetrofit then
                ObjectsCls[sender] = _cls;
                cls = _cls;
            end
            local meta = cls and ClassesMetas[cls][name] or oldMeta;
            if meta then
                return meta(sender,...);
            end
            error((i18n"This meta method is not implemented. - %s"):format(name));
        end);
    end
end

local function RetrofitExternalObjectMeta(cls,metas,forceRetrofit)
    if rawget(metas,__cls__) then
        return;
    end
    rawset(metas,__cls__,cls);
    -- Attempt to retrofit the meta-table.
    -- Only __index and __newindex will integrate the logic,
    -- the logic of other meta methods will be overwritten.
    for name,_ in pairs(Meta) do
        RetrofiteMetaMethod(cls,metas,name,forceRetrofit);
    end

    local index = rawget(metas,"__index");
    local indexFunc = "function" == type(index);
    local newIndex = rawget(metas,"__newindex");
    local newIndexFunc =  "function" == type(newIndex);
    rawset(metas,"__index",function (sender,key)
        local oCls = ObjectsCls[sender];
        if nil == oCls and forceRetrofit then
            ObjectsCls[sender] = cls;
            oCls = cls;
        end
        if oCls then
            if key == handlers then
                HandlersControlObj = sender;
                return HandlersControl;
            end

            -- Check self all.
            local all = AllObjects[sender];
            local ret = nil;
            if all then
                ret = all[key];
                if nil ~= ret then
                    return ret;
                end
            end

            -- Check cls methods and members.
            ret = rawget(oCls,key);
            if nil ~= ret then
                return ret;
            end

            -- Check cls properties.
            local property = ClassesReadable[oCls][key];
            if property and not property[2] then
                return property[1](sender);
            end
            -- Check cls bases.
            for _, base in ipairs(ClassesBases[oCls]) do
                ret = CascadeGet(base,key,{},true);
                if nil ~= ret then
                    return ret;
                end
            end
        end
        -- Finally, check the original method or table.
        if index then
            if indexFunc then
                return index(sender,key);
            end
            return index[key];
        end
    end);
    rawset(metas,"__newindex",function (sender,key,value)
        local oCls = ObjectsCls[sender];
        if nil == oCls and forceRetrofit then
            ObjectsCls[sender] = cls;
            oCls = cls;
        end
        if oCls then
            local property = ClassesWritable[oCls][key];
            if property and not property[2] then
                property[1](sender,value);
                return;
            end
            local all = AllObjects[sender];
            if all == nil and forceRetrofit then
                all = {};
                AllObjects[sender] = all;
            end
            all[key] = value;
        else
             -- Finally, write by the original method.
            if newIndex then
                if newIndexFunc then
                    newIndex(sender,key,value);
                elseif newIndex then
                    newIndex[key] = value;
                end
            else
                local t = type(sender);
                if "table" == t then
                    rawset(sender,key,value);
                else
                    error((i18n"attempt to index a %s value."):format(t));
                end
            end
        end
    end);
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
local function CascadeDelete(self,cls,called)
    if called[cls] then
        return;
    end
    local del = rawget(cls,dtor);
    if del then
        del(self);
    end
    called[cls] = true;
    local bases = ClassesBases[cls];
    if bases then
        for _,base in ipairs(bases) do
            CascadeDelete(self,base,called);
        end
    end
end

local function CallDel(self)
    CascadeDelete(self,self[is](),{});
    DeathMark[self] = true;
    AllObjects[self] = nil;
end

local CreateClassDelete = ClearMembersInRelease and function(cls)
    return function (self)
        CascadeDelete(self,cls,{});
        local d = ClassesDelete[cls];
        if d then
            d(self);
        else
            local ut = "userdata" == type(self);
            if ut then
                d_setmetatable(self,nil);
            else
                setmetatable(self,nil);
                for k,_ in pairs(self) do
                    self[k] = nil;
                end
            end
        end
        DeathMark[self] = true;
            AllObjects[self] = nil;
    end
end or
function (cls)
    return function (self)
        CascadeDelete(self,cls,{});
        local d = ClassesDelete[cls];
        if d then
            d(self);
        else
            ("userdata" == type(self) and d_setmetatable or setmetatable)(self,nil);
        end
        DeathMark[self] = true;
            AllObjects[self] = nil;
    end
end

---Create a class table with base info.
---
---@param cls table
---@return table @all
---@return table @bases
---@return table @handlers
---@return table @members
---@return table @r
---@return table @w
---
local function CreateClassTables(cls)
    local bases = {};
    local handlers = setmetatable({},{
        __newindex = function (h,k,v)
            rawset(h,k,v);
            Update2ChildrenWithKey(cls,ClassesHandlers,k,v);
        end
    });
    local members = {};

    AllClasses[cls] = true;
    ClassesBases[cls] = bases;
    ClassesChildren[cls] = {};
    ClassesHandlers[cls] = handlers;
    ClassesStatic[cls] = {};

    local r,w = CreateClassPropertiesTable(cls,bases);
    ClassesReadable[cls] = r;
    ClassesWritable[cls] = w;
    ClassesMembers[cls] = members;

    return cls,bases,handlers,members,r,w;
end

local function AttachClassFunctions(cls,_is,_new,_delete)
    local static = ClassesStatic[cls];
    cls[is] = _is;
    static[new] = {_new};
    cls[delete] = _delete;
end

local function ClassInherite(cls,args,bases,handlers,members,metas,name,pb)
    local children = ClassesChildrenByName[name];
    if children then
        -- If some class inherits by name before that class is defined,
        -- update the bases table and children table here.
        ClassesChildren[cls] = children;
        ClassesChildrenByName[name] = nil;
        for _,child in ipairs(children) do
            insert(ClassesBases[child],cls);
        end
    end
    for _, base in ipairs(args) do
        if "string" == type(base) then
            local baseName = base;
            base = NamedClasses[base];
            if nil == base then
                -- If there is no class named 'base',record it in ClassesChildrenByName.
                -- When the class which named 'base' is created,push 'base' into cls bases table.
                ClassesChildrenByName[baseName] = ClassesChildrenByName[baseName] or {};
                insert(ClassesChildrenByName[baseName],cls);
            end
        end
        if nil ~= base then
            (pb or PushBase)(cls,bases,base,handlers,members,metas);
        end
    end
end

---In non-debug mode, no access qualifiers are considered.
---
---@param cls table
---@param key any
---@return any
---
local function ClassGet(cls,key)
    if BitsMap[key] then
        return Begin(Router,cls,key);
    end
    if key == handlers then
        return ClassesHandlers[cls];
    end
    -- Check the properties first.
    local property = ClassesReadable[cls][key];
    if property and property[2] then
        -- Is static property?
        -- Class can't access object's property directly.
        return property[1](cls);
    end
    local ret = ClassesStatic[cls][key];
    if nil ~= ret then
        return ret[1];
    end
    ret = ClassesMembers[cls][key];
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
    if key == __singleton then
        -- Register "Instance" automatically.
        cls[static][get][Instance] = function ()
            return GetSingleton(cls,value);
        end;
        cls[static][set][Instance] = function (_,val)
            DestroySingleton(cls,val);
        end;
        return;
    elseif key == __new then
        ClassesNew[cls] = value;
        Update2Children(cls,ClassesNew,value);
        return;
    elseif key == __delete then
        ClassesDelete[cls] = value;
        Update2Children(cls,ClassesDelete,value);
        return;
    elseif key == friends or nil == key then
        return;
    else
        local property = ClassesWritable[cls][key];
        if property and property[2] then
            -- Is static property?
            -- Class can't access object's property directly.
            property[1](cls,value);
            return;
        end
        local meta = MetaMapName[key];
        if meta then
            ClassesMetas[cls][meta] = value;
            Update2ChildrenWithKey(cls,ClassesMetas,meta,value);
            return;
        end
        local cs = ClassesStatic[cls];
        local isStatic = cs[key] ~= nil;
        if not isStatic then
            local exist = rawget(cls,key);
            local vt = type(value);
            local isFunction = "function" == vt;
            local isTable = "table" == vt;
            if not exist and not isFunction and (not isTable or (not AllEnumerations[value] and not AllClasses[value])) then
                ClassesMembers[cls][key] = value;
                Update2ChildrenWithKey(cls,ClassesMembers,key,value);
            end
            if isFunction then
                rawset(cls,key,value);
            end
        else
            cs[key][1] = value;
        end
    end
end

Functions.class = class;
Functions.GetSingleton = GetSingleton;
Functions.DestroySingleton = DestroySingleton;
Functions.CheckClass = CheckClass;
Functions.PushBase = PushBase;
Functions.CreateClassIs = CreateClassIs;
Functions.CreateClassDelete = CreateClassDelete;
Functions.CreateClassObject = CreateClassObject;
Functions.CallDel = CallDel;
Functions.MakeInternalObjectMeta = MakeInternalObjectMeta;
Functions.RegisterHandlersAndMembers = RegisterHandlersAndMembers;
Functions.RetrofitExternalObjectMeta = RetrofitExternalObjectMeta;
Functions.RetrofiteMetaMethod = RetrofiteMetaMethod;
Functions.CreateClassTables = CreateClassTables;
Functions.AttachClassFunctions = AttachClassFunctions;
Functions.ClassInherite = ClassInherite;
Functions.ClassGet = ClassGet;
Functions.ClassSet = ClassSet;
Functions.CascadeDelete = CascadeDelete;

return Functions;