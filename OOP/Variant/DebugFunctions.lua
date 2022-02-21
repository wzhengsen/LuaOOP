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
local d_setmetatable = debug.setmetatable;
local rawset = rawset;
local rawget = rawget;
local rawequal = rawequal;
local type = type;
local pairs = pairs;
local ipairs = ipairs;
local warn = warn or print;

local Config = require("OOP.Config");
local i18n = require("OOP.i18n");

local BaseFunctions = require("OOP.BaseFunctions");
local bits = BaseFunctions.bits;
local band = bits.band;
local FunctionWrapper = BaseFunctions.FunctionWrapper;
local Update2Children = BaseFunctions.Update2Children;
local Update2ChildrenWithKey = BaseFunctions.Update2ChildrenWithKey;
local CheckPermission = BaseFunctions.CheckPermission;

local E_Handlers = require("OOP.Event").handlers;

local R = require("OOP.Router");
local Router = R.Router;
local BitsMap = R.BitsMap;
local Permission = R.Permission;
local Begin = R.Begin;

local new = Config.new;
local delete = Config.delete;
local nNew = "n" .. new;
local nDelete = "n" .. delete;
local is = Config.is;
local ctor = Config.ctor;
local dtor = Config.dtor;
local nCtor = "n" .. ctor;
local nDtor = "n" .. dtor;
local __new = Config.__new;
local __delete = Config.__delete;
local __cls__ = Config.__cls__;

local static = Config.Qualifiers.static;
local get = Config.get;
local set = Config.set;

local friends = Config.friends;
local __singleton = Config.__singleton;
local Instance = Config.Instance;
local handlers = Config.handlers;
local Meta = Config.Meta;

local MetaMapName = Config.MetaMapName;

local PropertyBehavior = Config.PropertyBehavior;

local Functions = require("OOP.Variant.ReleaseFunctions");
local R_GetSingleton = Functions.GetSingleton;
local R_DestroySingleton = Functions.DestroySingleton;
local R_RetrofiteMetaMethod = Functions.RetrofiteMetaMethod;
local R_ClassInherite = Functions.ClassInherite;
local R_PushBase = Functions.PushBase;
local R_CreateClassObject = Functions.CreateClassObject;
local R_CreateClassTables = Functions.CreateClassTables;
local FinalClassesMembers = Functions.FinalClassesMembers;
local VirtualClassesMembers = Functions.VirtualClassesMembers;
local VirtualClassesPermissons = Functions.VirtualClassesPermissons;
local NamedClasses = Functions.NamedClasses;
local AllClasses = Functions.AllClasses;
local AllEnumerations = Functions.AllEnumerations;
local FinalClasses = Functions.FinalClasses;
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
local ClassesStatic = Functions.ClassesStatic;
local ClassesChildrenByName = Functions.ClassesChildrenByName;

local ClassesAll = Functions.ClassesAll;
local ClassesPermissions = Functions.ClassesPermissions;
local ClassesFriends = Functions.ClassesFriends;
local ClassesAllFunctions = Functions.ClassesAllFunctions;
local ClassesAllMetaFunctions = Functions.ClassesAllMetaFunctions;
local WeakTables = Functions.WeakTables;
local AccessStack = Functions.AccessStack;
local DeathMark = Functions.DeathMark;

local ReservedWord = Functions.ReservedWord;

local p_public = Permission.public;
local p_protected = Permission.protected;
local p_private = Permission.private;
local p_static = Permission.static;

local class = require("OOP.BaseClass");
local c_delete = class.delete;

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
    local all = ClassesAll[cls];
    if nil ~= all then
        ret = all[key];
        if nil ~= ret then
            return ret;
        end
        if not byObject then
            ret = ClassesStatic[cls];
            if ret then
                ret = ret[key];
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
    else
        ret = ClassesStatic[cls];
        if ret then
            ret = ret[key];
            if nil ~= ret then
                return ret[1];
            end
        end
    end
end

local HandlersControlObj = nil;
local HandlersControl = setmetatable({},{
    __newindex = function (_,key,value)
        if nil == HandlersControlObj then
            return;
        end
        if "string" ~= type(key) then
            error((i18n"The key of the object's %s must be a string"):format(handlers));
        end
        local vt = type(value);
        if nil == value then
            -- If value is nil,we remove the response of this event name.
            E_Handlers.Remove(key,HandlersControlObj);
        elseif value == false or value == true then
            -- If value is a boolean,we enable/disable it.
            E_Handlers.Enabled(key,HandlersControlObj,value);
        elseif vt == "function" then
            -- If value is a function,we reset the response of this event name.
            E_Handlers.Remove(key,HandlersControlObj);
            E_Handlers.On(key,HandlersControlObj,FunctionWrapper(HandlersControlObj[is](),value));
        elseif vt == "number" then
            -- If value is a number,we sort it.
            E_Handlers.Order(key,HandlersControlObj,math.floor(value));
        else
            error((i18n"The object's %s can only accpet number/function/boolean/nil."):format(handlers));
        end
    end
});

local function GetAndCheck(cls,sender,key)
    if key == nil then return nil; end
    if key == handlers then
        HandlersControlObj = sender;
        return HandlersControl;
    end
    -- Check the properties of current class.
    local pre = "n";
    local property = ClassesReadable[cls][key];
    if property and not property[2] then
        pre = "g";
    end

    if not CheckPermission(cls,pre .. key) then
        return nil;
    end

    -- Check self __all__ first.
    -- Some objects may be created externally and have no 'all' table,
    -- so create one manually at this point.
    local all = ObjectsAll[sender];
    if nil == all then
        all = {};
        ObjectsAll[sender] = all;
    end
    local ret = all[key];
    if nil ~= ret then
        return ret;
    end
    -- Check the key of current class.
    ret = rawget(cls,key);
    if nil ~= ret then
        return ret;
    end

    if pre == "g" then
        return property[1](sender);
    else
        property = ClassesWritable[cls][key];
        if property and not property[2] then
            if PropertyBehavior ~= 2 then
                if PropertyBehavior == 0 then
                    warn(("You can't read a write-only property. - %s"):format(key));
                elseif PropertyBehavior == 1 then
                    error((i18n"You can't read a write-only property. - %s"):format(key));
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
        ret = CascadeGet(base,key,{},true);
        if nil ~= ret then
            return ret;
        end
    end
end

local function SetAndCheck(cls,sender,key,value)
    if key == nil then return; end
    -- The reserved words cannot be used.
    if ReservedWord[key] then
        error((i18n"%s is a reserved word and you can't set it."):format(key));
    end
    local pre = "n";
    local property = ClassesWritable[cls][key];
    if property and not property[2] then
        pre = "s";
    end
    if not CheckPermission(cls,pre .. key,true,true) then
        return;
    end
    if pre == "s" then
        property[1](sender,value);
        return;
    else
        property = ClassesReadable[cls][key];
        if property and not property[2] then
            if PropertyBehavior ~= 2 then
                if PropertyBehavior == 0 then
                    warn(("You can't write a read-only property. - %s"):format(key));
                elseif PropertyBehavior == 1 then
                    error((i18n"You can't write a read-only property. - %s"):format(key));
                end
                return;
            end
        end
    end
    -- Some objects may be created externally and have no 'all' table,
    -- so create one manually at this point.
    local all = ObjectsAll[sender];
    if nil == all then
        all = {};
        ObjectsAll[sender] = all;
    end
    all[key] = value;
end

---
---Generate a meta-table for an object (typically a table) generated by a pure lua class.
---
---@param cls table
---@param metas? table
---
local function MakeInternalObjectMeta(cls,metas)
    metas.__index = function (sender,key)
        return GetAndCheck(cls,sender,key);
    end;
    metas.__newindex = function (sender,key,value)
        SetAndCheck(cls,sender,key,value);
    end;
end

---
--- Retrofit userdata's meta-table to fit lua-class's hybrid inheritance pattern.
local function RetrofitExternalObjectMeta(cls,metas,forceRetrofit)
    if rawget(metas,__cls__) then
        return;
    end
    rawset(metas,__cls__,cls);
    -- Attempt to retrofit the meta-table.
    -- Only __index and __newindex will integrate the logic,
    -- the logic of other meta methods will be overwritten.
    for name,_ in pairs(Meta) do
        R_RetrofiteMetaMethod(cls,metas,name,forceRetrofit)
    end

    local index = rawget(metas,"__index");
    local newIndex = rawget(metas,"__newindex");
    local indexFunc = "function" == type(index);
    local newIndexFunc =  "function" == type(newIndex);
    rawset(metas,"__index",function(sender,key)
        local oCls = ObjectsCls[sender];
        if nil == oCls and forceRetrofit then
            ObjectsCls[sender] = cls;
            oCls = cls;
        end
        if oCls then
            local ret = GetAndCheck(oCls,sender,key);
            if nil ~= ret then
                return ret;
            end
        end
        -- Finally, check the original method or table.
        if index then
            if indexFunc then
                return index(sender,key);
            end
            return index[key];
        end
        return nil;
    end);
    rawset(metas,"__newindex",function (sender,key,value)
        local oCls = ObjectsCls[sender];
        if nil == oCls and forceRetrofit then
            ObjectsCls[sender] = cls;
            oCls = cls;
        end
        if oCls then
            SetAndCheck(oCls,sender,key,value);
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

local function ClassGet(cls,key)
    if nil == key then return nil; end
    if BitsMap[key] then
        return Begin(Router,cls,key);
    end
    if key == handlers then
        return ClassesHandlers[cls];
    elseif key == friends then
        local fri = ClassesFriends[cls];
        if nil == fri then
            fri = {};
            ClassesFriends[cls] = fri;
        end
        return fri;
    end
    -- Check the properties first.
    local property = ClassesReadable[cls][key];
    if not CheckPermission(cls,(property and "g" or "n") .. key) then
        return;
    end

    if property then
        if property[2] then
            return property[1](cls);
        end
    else
        property = ClassesWritable[cls][key];
        if property and property[2] then
            if PropertyBehavior ~= 2 then
                if PropertyBehavior == 0 then
                    warn(("You can't read a write-only property. - %s"):format(key));
                elseif PropertyBehavior == 1 then
                    error((i18n"You can't read a write-only property. - %s"):format(key));
                end
                return nil;
            end
        end
    end
    local ret = ClassesAll[cls][key];
    if nil ~= ret then
        return ret;
    end
    ret = ClassesStatic[cls][key];
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

local function DestroySingleton(cls,val)
    assert(nil == val,i18n"The nil value needs to be passed in to destory the object.");
    R_DestroySingleton(cls,val);
end

local function ClassSet(cls,key,value)
    if nil == key then return;end
    -- The reserved words cannot be used.
    if ReservedWord[key] then
        error((i18n"%s is a reserved word and you can't set it."):format(key));
    end
    local vKey = "n" .. key;
    if FinalClassesMembers[cls][vKey] then
        error((i18n"You cannot define final members again. - %s"):format(key));
    end

    if key == friends then
        if "table" ~= type(value) then
            error((i18n"%s reserved word must be assigned to a table."):format(key));
        end
        local fri = {};
        ClassesFriends[cls] = fri;
        for _,v in ipairs(value) do
            fri[v] = true;
        end
        return;
    end

    local vt = type(value);
    local isFunction = "function" == vt;

    if key == ctor or key == dtor then
        if not isFunction then
            error((i18n"%s reserved word must be assigned to a function."):format(key));
        end
        local isCtor = key == ctor;
        local ban = value == c_delete;
        local keyTable = isCtor and ClassesBanNew or ClassesBanDelete;
        keyTable[cls] = ban;
        Update2Children(cls,keyTable,ban);
    end

    if key == __singleton then
        if not isFunction then
            error((i18n"%s reserved word must be assigned to a function."):format(key));
        end
        -- Register "Instance" automatically.
        cls[static][get][Instance] = function()
            return R_GetSingleton(cls,value);
        end;
        cls[static][set][Instance] = function(_,val)
            DestroySingleton(cls,val)
        end;
        -- Once register "__singleton" for a class,set permission of "new","delete" method to protected.
        local pms = ClassesPermissions[cls];
        local pm = pms[nNew];
        if band(pm,p_private) == 0 then
            pms[nNew] = p_static + p_protected;
        end
        pms[nDelete] = p_protected;
        return;
    elseif key == __new then
        if not isFunction then
            error((i18n"%s reserved word must be assigned to a function."):format(key));
        end
        value = FunctionWrapper(cls,value);
        ClassesNew[cls] = value;
        Update2Children(cls,ClassesNew,value);
        return;
    elseif key == __delete then
        if not isFunction then
            error((i18n"%s reserved word must be assigned to a function."):format(key));
        end
        value = FunctionWrapper(cls,value);
        ClassesDelete[cls] = value;
        Update2Children(cls,ClassesDelete,value);
        return;
    else
        local vPermisson = VirtualClassesPermissons[cls][vKey];
        if vPermisson then
            -- Check pure virtual functions.
            if not isFunction then
                error((i18n"%s must be overridden as a function."):format(key));
            elseif vPermisson ~= p_public then
                error((i18n"A different access qualifier is used when you override pure virtual functions. - %s"):format(key));
            end
            VirtualClassesMembers[cls][vKey] = nil;
            Update2ChildrenWithKey(cls,VirtualClassesMembers,vKey,nil,true);
        else
            local property = ClassesWritable[cls][key];
            if not CheckPermission(cls,(property and "s" or "n") .. key,true) then
                return;
            end
            if property then
                if property[2] then
                    property[1](cls,value);
                    return;
                end
            else
                property = ClassesWritable[cls][key];
                if property and property[2] then
                    if PropertyBehavior ~= 2 then
                        if PropertyBehavior == 0 then
                            warn(("You can't write a read-only property. - %s"):format(key));
                        elseif PropertyBehavior == 1 then
                            error((i18n"You can't write a read-only property. - %s"):format(key));
                        end
                        return;
                    end
                end
            end
        end

        if isFunction then
            -- Wrap this function to include control of access permission.
            value = FunctionWrapper(cls,value);
        end

        local meta = MetaMapName[key];
        if meta then
            local metas = ClassesMetas[cls];
            metas[meta] = value;
            Update2ChildrenWithKey(cls,ClassesMetas,meta,value);
            ClassesPermissions[cls][vKey] = p_public;
            return;
        end
        local cs = ClassesStatic[cls];
        local isStatic = cs[key] ~= nil;
        if not isStatic then
            local all = ClassesAll[cls];
            local exist = all[key];
            if not exist then
                local isTable = "table" == vt;
                if not isFunction and (not isTable or (not AllEnumerations[value] and not AllClasses[value])) then
                    ClassesMembers[cls][key] = value;
                    Update2ChildrenWithKey(cls,ClassesMembers,key,value);
                end
                ClassesPermissions[cls][vKey] = p_public;
            end
            if isFunction then
                all[key] = value;
            end
        else
            cs[key][1] = value;
        end
    end
end

local function MakeClassHandlersTable(cls,handlers,bases)
    -- Putting the response function in p for override the response function of the base class
    -- allows you to use the current class to wrap the response function.
    local p = {};
    return setmetatable(handlers,{
        __newindex = function(t,key,value)
            if not ("string" == type(key)) then
                error(i18n"The name of handler function must be a string.")
            end
            assert("function" == type(value),i18n"event handler must be a function.");
            -- Ensure that event response functions have access to member variables.
            value = FunctionWrapper(cls,value)
            rawset(p,key,value);
            Update2ChildrenWithKey(cls,ClassesHandlers,key,value);
        end,
        __index = function (_,key)
            local ret = p[key];
            if nil ~= ret then
                return ret;
            end
            for _,base in ipairs(bases) do
                ret = ClassesHandlers[base];
                if nil ~= ret then
                    ret = ret[key];
                    if nil ~= ret then
                        return ret;
                    end
                end
            end
        end,
        __pairs = function ()
            return pairs(p);
        end
    });
end

local function CreateClassTables(cls)
    local all,bases,handlers,members,r,w = R_CreateClassTables(cls);

    MakeClassHandlersTable(cls,handlers);
    all = {}
    ClassesAll[cls] = all;
    ClassesPermissions[cls] = {};
    ClassesAllFunctions[cls] = setmetatable({},WeakTables);
    ClassesAllMetaFunctions[cls] = setmetatable({},WeakTables);
    FinalClassesMembers[cls] = {};
    VirtualClassesMembers[cls] = {};
    VirtualClassesPermissons[cls] = {};

    return all,bases,handlers,members,r,w;
end

local function PushBase(cls,bases,base,handlers,members,meta)
    R_PushBase(cls,bases,base,handlers,members,meta);
    local fm = FinalClassesMembers[cls];
    local vm = VirtualClassesMembers[cls];
    local vp = VirtualClassesPermissons[cls];
    local pms = ClassesPermissions[base];
    if ClassesBanNew[base] then
        ClassesBanNew[cls] = true;
    elseif pms then
        local pm = pms[nCtor];
        if pm and band(pm,p_private) ~= 0 then
            ClassesBanNew[cls] = true;
        end
    end

    if ClassesBanDelete[base] then
        ClassesBanDelete[cls] = true;
    elseif pms then
        local pm = pms[nDtor];
        if pm and band(pm,p_private) ~= 0 then
            ClassesBanDelete[cls] = true;
        end
    end
    local fcm = FinalClassesMembers[base];
    if fcm then
        for k,_ in pairs(fcm) do
            fm[k] = true;
        end
    end

    local fri = ClassesFriends[base];
    if fri then
        local cls_fri = ClassesFriends[cls];
        if nil == cls_fri then
            cls_fri = {};
            ClassesFriends[cls] = cls_fri;
        end
        for friend,_ in pairs(fri) do
            cls_fri[friend] = true;
        end
    end

    local vcm = VirtualClassesMembers[base];
    if vcm then
        for k,v in pairs(vcm) do
            vm[k] = v;
        end
    end

    local vcp = VirtualClassesPermissons[base];
    if vcp then
        for k,v in pairs(vcp) do
            if nil == vp[k] then
                vp[k] = v;
            end
        end
    end
end

local function ClassInherite(cls,args,bases,handlers,members,meta,name)
    if FinalClasses[name] and ClassesChildrenByName[name] then
        error(i18n"You cannot inherit a final class.");
    end
    for idx, base in ipairs(args) do
        local baseType = type(base);
        assert(
            baseType == "table"
            or baseType == "string",
            i18n"Unavailable base class type."
        );
        assert(not FinalClasses[base],i18n"You cannot inherit a final class.");
        for i,b in ipairs(args) do
            if idx ~= i then
                if type(b) == "string" then
                    local namedCls = NamedClasses[b];
                    if namedCls then
                        b = namedCls;
                    end
                end
                if b == base then
                    error(i18n"It is not possible to inherit from the same class repeatedly.");
                end
            end
        end
    end
    R_ClassInherite(cls,args,bases,handlers,members,meta,name,PushBase);
end

local function CreateClassObject(...)
    local obj,all = R_CreateClassObject(...);
    if (nil ~= obj) and rawequal(obj,all) then
        all = ObjectsAll[obj];
        if nil == all then
            all = {};
            ObjectsAll[obj] = all;
        end
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

    local pm = ClassesPermissions[cls][nDtor];
    if pm then
        local aCls = AccessStack[#AccessStack];
        local _friends = ClassesFriends[cls];
        if (not _friends or (not _friends[aCls] and not _friends[NamedClasses[cls]])) and
        (band(pm,p_public) == 0) and
        (aCls ~= cls) and
        (band(pm,p_private) ~= 0)then
            error((i18n"Attempt to access private members outside the permission. - %s"):format(dtor));
        end
    end

    -- Since the meta method is not triggered here,
    -- it is necessary to determine the permission in advance.
    local del = ClassesAll[cls][dtor];
    if del then
        del(obj);
    end
    called[cls] = true;

    local bases = ClassesBases[cls];
    if bases then
        for _,base in ipairs(bases) do
            CascadeDelete(obj,base,called);
        end
    end
end

local function CallDel(self)
    CascadeDelete(self,self[is](),{});
    DeathMark[self] = true;
    ObjectsAll[self] = nil;
end

local function CreateClassDelete(cls)
    return function (self)
        if ClassesBanDelete[cls] then
            error(i18n"The class/base classes destructor is not accessible.");
        end
        CascadeDelete(self,cls,{});
        local d = ClassesDelete[cls];
        if d then
            d(self);
        else
            ("userdata" == type(self) and d_setmetatable or setmetatable)(self,nil);
        end
        DeathMark[self] = true;
        ObjectsAll[self] = nil;
    end;
end

local function AttachClassFunctions(cls,_is,_new,_delete)
    local all = ClassesAll[cls];
    local static = ClassesStatic[cls];
    local pms = ClassesPermissions[cls];
    all[is] = _is;
    pms[is] = p_public;
    -- In debug mode,the "new" method is public and static.
    static[new] = {FunctionWrapper(cls,_new)};
    -- Use + instead of | to try to keep lua 5.3 or lower compatible.
    pms[nNew] = p_public + p_static;

    all[delete] = FunctionWrapper(cls,_delete);
    pms[nDelete] = p_public;
end

Functions.RetrofitExternalObjectMeta = RetrofitExternalObjectMeta;
Functions.MakeInternalObjectMeta = MakeInternalObjectMeta;
Functions.PushBase = PushBase;
Functions.CreateClassTables = CreateClassTables;
Functions.ClassInherite = ClassInherite;
Functions.CreateClassObject = CreateClassObject;
Functions.ClassSet = ClassSet;
Functions.ClassGet = ClassGet;
Functions.CallDel = CallDel;
Functions.CreateClassDelete = CreateClassDelete;
Functions.AttachClassFunctions = AttachClassFunctions;
Functions.DestroySingleton = DestroySingleton;

return Functions;