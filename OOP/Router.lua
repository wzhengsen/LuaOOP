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

local rawset = rawset;
local error = error;
local type = type;
local getmetatable = getmetatable;
local setmetatable = setmetatable;
local Config = require("OOP.Config");

local i18n = require("OOP.i18n");
local Internal = require("OOP.Variant.Internal");
local ClassesMembers = Internal.ClassesMembers;

local BaseFunctions = require("OOP.BaseFunctions");
local bits = BaseFunctions.bits;
local band = bits.band;
local bor = bits.bor;
local Debug = Config.Debug;

local MetaMapName = Config.MetaMapName;
local AllEnumerations = Internal.AllEnumerations;
local AllClasses = Internal.AllClasses;
local ClassesReadable = Internal.ClassesReadable;
local ClassesWritable = Internal.ClassesWritable;
local ClassesStatic = Internal.ClassesStatic;

local Update2ChildrenClassMeta = BaseFunctions.Update2ChildrenClassMeta;
local Update2ChildrenWithKey = BaseFunctions.Update2ChildrenWithKey;

local BitsMap = Internal.BitsMap;
local Permission = Internal.Permission;

local new = Config.new;
local delete = Config.delete;

local static = Config.Qualifiers.static;
local get = Config.get;
local set = Config.set;
local GetPropertyAutoConst = Config.GetPropertyAutoConst;

local class = require("OOP.BaseClass");
local c_delete = class.delete;

local p_static = Permission.static;
local p_virtual = Permission.virtual;
local p_get = Permission.get;
local p_final = Permission.final;
local p_private = Permission.private;
local p_get_set = Permission.get + Permission.set;

local Router = {};

local Pass = nil;
local Done = nil;
local decor = 0;
local cls = 0;
local function Begin(self,outCls,key)
    decor = 0;
    cls = outCls;
    return Pass(self,key);
end

if Debug then
    local ctor = Config.ctor;
    local dtor = Config.dtor;

    local FunctionWrapper = BaseFunctions.FunctionWrapper;
    local Update2Children = BaseFunctions.Update2Children;
    local ClassesAll = Internal.ClassesAll;
    local CheckPermission = BaseFunctions.CheckPermission;
    local FinalClassesMembers = Internal.FinalClassesMembers;
    local ClassesPermissions = Internal.ClassesPermissions;
    local VirtualClassesMembers = Internal.VirtualClassesMembers;
    local ClassesBanNew = Internal.ClassesBanNew;
    local ClassesBanDelete = Internal.ClassesBanDelete;

    local RouterReservedWord = Internal.RouterReservedWord;

    local p_const = Permission.const;
    local p_internalConstMethod = Internal.BitsMap.__InternalConstMethod;
    local bitMax = Internal.BitsMap.max;
    -- It is only under debug that the values need to be routed to the corresponding fields of the types.
    -- To save performance, all qualifiers will be ignored under non-debug.

    -- Rules:
    -- 1 - There can be no duplicate qualifiers;
    -- 2 - public/private/protected cannot be used together;
    -- 3 - static cannot qualify constructors and destructors;
    -- 4 - Can't use qualifiers that don't exist;
    -- 5 - Reserved words cannot be modified (__singleton__/friends/handlers).
    Pass = function(self,key)
        local bit = BitsMap[key];
        if bit then
            if band(decor,bit) ~= 0 then
                error((i18n"The %s qualifier is not reusable."):format(key));
            elseif band(decor,0x7) ~= 0 and band(bit,0x7) ~= 0 then
                -- Check public,private,protected,they are 0x7
                error((i18n"The %s qualifier cannot be used in conjunction with other access qualifiers."):format(key));
            elseif band(decor,0xc0) ~= 0 and band(bit,0xc0) ~= 0 then
                -- Check set,get,they are 0xc0
                error((i18n"%s,%s cannot be used at the same time."):format(get,set));
            else
                local temp = bor(bit,decor);
                if band(temp,p_virtual) ~= 0 and band(temp,bitMax) ~= p_virtual then
                    error(i18n"It is not necessary to use pure virtual functions with other qualifiers.");
                end
            end
            decor = bor(decor,bit);
        else
            local get_set = band(decor,p_get_set);
            if get_set ~= 0 then
                if bor(decor,p_get_set) == p_get_set then
                    CheckPermission(cls,key);
                    local property = (get_set == p_get and ClassesReadable or ClassesWritable)[cls][key];
                    if property then
                        return property[1];
                    else
                        error((i18n"There is no such property. - %s"):format(key));
                    end
                end
            end
            error((i18n"There is no such qualifier. - %s"):format(key));
        end
        return self;
    end
    Done = function(_,key,value)
        if FinalClassesMembers[cls][key] then
            error((i18n"You cannot define final members again. - %s"):format(key));
        end
        local bit = BitsMap[key] or RouterReservedWord[key];
        if bit then
            error((i18n"The name is unavailable. - %s"):format(key));
        end
        local meta = MetaMapName[key];
        if meta then
            if decor == p_static then
                -- Meta methods are special and can only accept static qualifiers.
                local mt = getmetatable(cls);
                value = FunctionWrapper(cls,value);
                mt[meta] = value;
                Update2ChildrenClassMeta(cls,meta,value);
                return;
            else
                error((i18n"You cannot qualify meta-methods. - %s"):format(key));
            end
        end
        local vcm = VirtualClassesMembers[cls];
        if decor == p_virtual then
            if value ~= 0 then
                error((i18n"The pure virtual function %s must be assigned a value of 0."):format(key));
            end
            vcm[key] = true;
            Update2ChildrenWithKey(cls,VirtualClassesMembers,key,true);
            return;
        end
        local isStatic = band(decor,p_static) ~= 0;
        if isStatic and
        (key == ctor or key == dtor) then
            error((i18n"%s qualifier cannot qualify %s method."):format(static,key));
        end
        if band(decor,0x7) == 0 then
            -- Without the public qualifier, public is added by default.
            decor = bor(decor,0x1);
        end
        local vt = type(value);
        local isFunction = "function" == vt;
        if vcm[key] then
            -- Check pure virtual functions.
            if not isFunction then
                error((i18n"%s must be overridden as a function."):format(key));
            end
            if isStatic then
                error((i18n"The pure virtual function %s cannot be overridden as a static function."):format(key));
            end
            vcm[key] = nil;
        end
        local get_set = band(decor,p_get_set);
        local isGet = get_set == p_get;
        local oVal = value;

        if isGet and GetPropertyAutoConst then
            decor = bor(decor,p_const);
        end

        if isFunction then
            local isConst = band(decor,p_const) ~= 0;
            value = FunctionWrapper(cls,value,nil,isConst);
            if isConst then
                -- Indicates that it is an internal const method.
                decor = bor(decor,p_internalConstMethod);
            end
        elseif get_set == 0 then
            local isTable = "table" == vt;
            -- For non-functional, non-static members,non-class objects,non-enumeration objects,
            -- add to the member table and generate it for each instance.
            if not isStatic and (not isTable or (not AllEnumerations[value] and not AllClasses[value])) then
                ClassesMembers[cls][key] = value;
                Update2ChildrenWithKey(cls,ClassesMembers,key,value);
            end
        end

        local pms = ClassesPermissions[cls];
        -- Instead of identifying the property with static,
        -- attach static to the property to avoid static checks occurring before taking the property
        -- (the property can have the same name as the static member).
        if isStatic then
            if get_set ~= 0 or ClassesReadable[cls][key] or ClassesWritable[cls][key] then
                decor = decor - p_static;
            end
        end
        local pm = pms[key];
        pms[key] = decor;
        if get_set ~= 0 then
            if not isFunction then
                error((i18n"A function must be assigned to the property %s."):format(key));
            end
            if key == ctor or key == dtor then
                error((i18n"%s and %s can't be used as property."):format(ctor,dtor));
            end
            -- The property is set to a special table
            -- with index 1 representing the function assigned to the property
            -- and index 2 representing whether the property is a static property.

            (isGet and ClassesReadable or ClassesWritable)[cls][key] = {value,isStatic};
        else
            local cs = ClassesStatic[cls];
            if isStatic then
                if pm and band(pm,p_static) == 0 and band(pm,p_get_set) == 0 then
                    error((i18n"Redefining static member %s is not allowed."):format(key));
                end
                local st = cs[key];
                if not st then
                    st = {value};
                    cs[key] = st;
                else
                    st[1] = value;
                end
            else
                if cs[key] ~= nil then
                    error((i18n"Redefining static member %s is not allowed."):format(key));
                end
                if isFunction or isStatic then
                    ClassesAll[cls][key] = value;
                end
            end

            if key == ctor then
                -- Reassign permissions to "new", which are the same as ctor with the static qualifier.
                pms[new] = bor(decor,0x8);
                local ban = band(decor,p_private) ~= 0 or oVal == c_delete;
                Update2Children(cls,ClassesBanNew,ban);
            elseif key == dtor then
                pms[delete] = decor;
                local ban = band(decor,p_private) ~= 0 or oVal == c_delete;
                Update2Children(cls,ClassesBanDelete,ban);
            end
        end

        if band(decor,p_final) ~= 0 then
            FinalClassesMembers[cls][key] = true;
            Update2ChildrenWithKey(cls,FinalClassesMembers,key,true);
        end
    end
else
    local ClassesMetas = Internal.ClassesMetas;
    -- In non-debug mode, no attention is paid to any qualifiers other than static.
    Pass = function(self,key)
        local bit = BitsMap[key];
        if bit then
            decor = bor(decor,bit);
        else
            local get_set = band(decor,p_get_set);
            if get_set ~= 0 then
                local property = (get_set == p_get and ClassesReadable or ClassesWritable)[cls][key];
                return property and property[1] or nil;
            end
        end
        return self;
    end
    Done = function(_,key,value)
        if band(decor,p_virtual) ~= 0 then
            -- Skip pure virtual functions.
            return;
        end
        local vt = type(value);
        local isFunction = "function" == vt;
        local isTable = "table" == vt;
        local isStatic = band(decor,p_static) ~= 0;
        local get_set = band(decor,p_get_set);
        if not isFunction and not isStatic and get_set == 0 and (not isTable or (not AllEnumerations[value] and not AllClasses[value])) then
            ClassesMembers[cls][key] = value;
            Update2ChildrenWithKey(cls,ClassesMembers,key,value);
        end

        if get_set ~= 0 then
            (get_set == p_get and ClassesReadable or ClassesWritable)[cls][key] = {value,isStatic};
        else
            local cs = ClassesStatic[cls];
            if isStatic then
                if rawget(cls,key) ~= nil then
                    -- Redefining static member is not allowed.
                    return;
                end
                local st = cs[key];
                if not st then
                    st = {value};
                    cs[key] = st;
                else
                    st[1] = value;
                end
            else
                if cs[key] then
                    -- Redefining static member is not allowed.
                    return;
                end
                if isFunction or isStatic then
                    rawset(cls,key,value);
                end
            end
        end


        local meta = MetaMapName[key];
        if meta then
            if decor == p_static then
                -- Meta methods are special and can only accept static qualifiers.
                local mt = getmetatable(cls);
                mt[meta] = value;
                Update2ChildrenClassMeta(cls,meta,value);
            else
                local metas = ClassesMetas[cls];
                metas[key] = value;
            end
        end
    end
end

setmetatable(Router,{
    __index = function (self,key)
        return Pass(self,key);
    end,
    __newindex = function (self,key,val)
        Done(self,key,val);
    end
});

return {
    Router = Router,
    BitsMap = BitsMap,
    Permission = Permission,
    Begin = Begin
};