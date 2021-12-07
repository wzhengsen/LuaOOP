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
local tostring = tostring;
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

local public = Config.Qualifiers.public;
local private = Config.Qualifiers.private;
local protected = Config.Qualifiers.protected;
local static = Config.Qualifiers.static;
local final = Config.Qualifiers.final;
local virtual = Config.Qualifiers.virtual;
local get = Config.get;
local set = Config.set;
local GetPropertyAutoConst = Config.GetPropertyAutoConst;

local class = require("OOP.BaseClass");
local c_delete = class.delete;

local p_public = Permission.public;
local p_private = Permission.private;
local p_protected = Permission.protected;
local p_static = Permission.static;
local p_virtual = Permission.virtual;
local p_get = Permission.get;
local p_final = Permission.final;
local p_gs = Permission.get + Permission.set;
local p_vf = Permission.virtual + Permission.final;
local p_3p = Permission.public + Permission.private + Permission.protected;
local p_gs_2p = p_gs + Permission.private + Permission.protected;

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
    local VirtualClassesPermissons = Internal.VirtualClassesPermissons;
    local ClassesBanNew = Internal.ClassesBanNew;
    local ClassesBanDelete = Internal.ClassesBanDelete;

    local RouterReservedWord = Internal.RouterReservedWord;

    local p_const = Permission.const;
    local p_internalConstMethod = Internal.BitsMap.__InternalConstMethod;
    -- It is only under debug that the values need to be routed to the corresponding fields of the types.
    -- To save performance, all qualifiers will be ignored under non-debug.

    -- Rules:
    -- 1 - public/private/protected cannot be used together;
    -- 2 - static cannot qualify constructors and destructors;
    -- 3 - Can't use qualifiers that don't exist;
    -- 4 - Reserved words cannot be modified (__singleton__/friends/handlers);
    -- 5 - (get/set) and (virtual/final) cannot be used together.
    Pass = function(self,key)
        local bit = BitsMap[key];
        if bit then
            decor = bor(decor,bit);
        else
            local gs = band(decor,p_gs);
            if gs ~= 0 then
                if bor(decor,p_gs) == p_gs then
                    CheckPermission(cls,key);
                    local property = (gs == p_get and ClassesReadable or ClassesWritable)[cls][key];
                    if property then
                        return property[1];
                    end
                    error((i18n"There is no such property. - %s"):format(key));
                end
            end
            error((i18n"There is no such qualifier. - %s"):format(key));
        end
        return self;
    end

    local function DoneMeta(meta,key,value)
    end

    Done = function(_,key,value)
        if band(decor,p_gs) == p_gs then
            -- Check set,get,they are p_gs
            error((i18n"%s,%s cannot be used at the same time."):format(get,set));
        elseif band(decor,p_vf) == p_vf then
            -- Check virtual,final,they are p_vf
            error((i18n"%s,%s cannot be used at the same time."):format(final,virtual));
        end

        local ppp_flag = band(decor,p_3p);
        if ppp_flag == 0 then
            -- Without the public qualifier, public is added by default.
            decor = bor(decor,p_public);
        elseif ppp_flag ~= p_public and ppp_flag ~= p_private and ppp_flag ~= p_protected then
            -- Check public,private,protected,they are p_3p
            error((i18n"The %s qualifier cannot be used in conjunction with other access qualifiers."):format(key));
        end

        local isStatic = band(decor,p_static) ~= 0;
        local isVirtual = band(decor,p_virtual) ~= 0;
        if isVirtual then
            if value ~= 0 then
                error((i18n"The pure virtual function %s must be assigned a value of 0."):format(key));
            elseif isStatic then
                error((i18n"The pure virtual function %s cannot be defined as a static function."):format(key));
            end
        end

        local meta = MetaMapName[key];
        if meta and band(decor,p_gs_2p) ~= 0 then
            error((i18n"You cannot qualify meta-methods with %s."):format(
                private .. "," .. protected .. "," .. get .. "," .. set
            ));
        end

        local gs = band(decor,p_gs);
        local vt = type(value);
        local isFunction = "function" == vt;
        local isGet = gs == p_get;
        local gsKey = key;
        if gs == 0 then
            -- 'n.' means the function is a normal one.
            gsKey = "n."..gsKey;
        elseif isGet then
            -- 'g.' means the function is a getter.
            -- 's.' means the function is a setter.
            gsKey = (isGet and "g." or "s.") ..gsKey;
        end

        if FinalClassesMembers[cls][gsKey] then
            error((i18n"You cannot define final members again. - %s"):format(key));
        end

        local bit = BitsMap[key] or RouterReservedWord[key];
        if bit then
            error((i18n"The name is unavailable. - %s"):format(key));
        end


        if isStatic and (key == ctor or key == dtor) then
            error((i18n"%s qualifier cannot qualify %s method."):format(static,key));
        end

        if isGet and GetPropertyAutoConst then
            decor = bor(decor,p_const);
        end

        local vcp = VirtualClassesPermissons[cls];
        if isVirtual then
            local vcm = VirtualClassesMembers[cls];
            local vPermisson = vcp[gsKey];
            -- Always update the permission of the virtual function.
            local vp = bor(decor,p_virtual) - p_virtual;
            vcp[gsKey] = vp;
            Update2ChildrenWithKey(cls,VirtualClassesPermissons,gsKey,vp,true);
            if nil == vPermisson or nil ~= vcm[gsKey] then
                -- But only update the member of virtual function if it is not nil,
                -- nil means that the virtual function is defined.
                vcm[gsKey] = true;
                Update2ChildrenWithKey(cls,VirtualClassesMembers,gsKey,true);
            end
            return;
        end

        if gs ~= 0 then
            if not isFunction then
                error((i18n"A function must be assigned to the property %s."):format(key));
            elseif key == ctor or key == dtor then
                error((i18n"%s and %s can't be used as property."):format(ctor,dtor));
            end
        end

        local vPermisson = vcp[gsKey];
        if vPermisson then
            local vcm = VirtualClassesMembers[cls];
            -- Check pure virtual functions.
            if not isFunction then
                error((i18n"%s must be overridden as a function."):format(key));
            elseif bor(decor,p_final) - p_final ~= vPermisson then
                error((i18n"A different access qualifier is used when you override pure virtual functions. - %s"):format(key));
            end
            vcm[gsKey] = nil;
            Update2ChildrenWithKey(cls,VirtualClassesMembers,gsKey,nil,true);
        end

        local oVal = value;
        local isConst = band(decor,p_const) ~= 0;
        local pms = ClassesPermissions[cls];

        if isFunction then
            value = FunctionWrapper(cls,value,nil,isConst);
            if isConst then
                -- Indicates that it is an internal const method.
                decor = bor(decor,p_internalConstMethod);
            end
        end

        if meta and isStatic then
            local mt = getmetatable(cls);
            mt[meta] = value;
            Update2ChildrenClassMeta(cls,meta,value);
            pms[key] = decor;
        else
            -- For non-functional, non-static members,non-class objects,non-enumeration objects,
            -- add to the member table and generate it for each instance.
            if not isFunction and not isStatic and ("table" ~= vt or (not AllEnumerations[value] and not AllClasses[value])) then
                ClassesMembers[cls][key] = value;
                Update2ChildrenWithKey(cls,ClassesMembers,key,value);
            end

            local pm = pms[key];
            if gs ~= 0 then
                -- The property is set to a special table
                -- with index 1 representing the function assigned to the property
                -- and index 2 representing whether the property is a static property.
                (isGet and ClassesReadable or ClassesWritable)[cls][key] = {value,isStatic};
            else
                local cs = ClassesStatic[cls];
                if isStatic then
                    -- Consider the following case:
                    -- local T = class();
                    -- function T.get:x()
                    -- end
                    -- T.static.x = 2;-- allowed,Because the property can have the same name as the static member.
                    -- function T:y()
                    -- end
                    -- T.static.y = 2;-- error
                    if pm and band(pm,p_static) == 0 and band(pm,p_gs) == 0 then
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
                    if isFunction then
                        ClassesAll[cls][key] = value;
                    end
                end

                if key == ctor then
                    -- Reassign permissions to "new", which are the same as ctor with the static qualifier.
                    pms[new] = bor(decor,p_static);
                    local ban = band(decor,p_private) ~= 0 or oVal == c_delete;
                    Update2Children(cls,ClassesBanNew,ban);
                elseif key == dtor then
                    pms[delete] = decor;
                    local ban = band(decor,p_private) ~= 0 or oVal == c_delete;
                    Update2Children(cls,ClassesBanDelete,ban);
                end
            end
            pms[key] = decor;
        end

        if band(decor,p_final) ~= 0 then
            FinalClassesMembers[cls][gsKey] = true;
            Update2ChildrenWithKey(cls,FinalClassesMembers,gsKey,true);
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
            local get_set = band(decor,p_gs);
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
        local get_set = band(decor,p_gs);
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