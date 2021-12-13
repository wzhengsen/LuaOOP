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
local ClassesMetas = Internal.ClassesMetas;

local Update2ChildrenClassMeta = BaseFunctions.Update2ChildrenClassMeta;
local Update2ChildrenWithKey = BaseFunctions.Update2ChildrenWithKey;

local BitsMap = Internal.BitsMap;
local Permission = Internal.Permission;

local new = Config.new;
local delete = Config.delete;
local nNew = "n" .. new;
local nDelete = "n" .. delete;

local static = Config.Qualifiers.static;
local final = Config.Qualifiers.final;
local virtual = Config.Qualifiers.virtual;
local override = Config.Qualifiers.override;
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
local p_override = Permission.override;
local p_get = Permission.get;
local p_set = Permission.set;
local p_final = Permission.final;
local p_gs = Permission.get + Permission.set;
local p_vf = Permission.virtual + Permission.final;
local p_3p = Permission.public + Permission.private + Permission.protected;

local Router = {};

local Pass = nil;
local Done = nil;
local virtualKey = nil;
local decor = 0;
local cls = 0;
local function Begin(self,outCls,key)
    decor = 0;
    cls = outCls;
    return Pass(self,key);
end

if Debug then
    local signMap = {
        s = "string",
        n = "number",
        i = "integer",
        d = "float",
        v = "nil",
        f = "function",
        t = "table",
        b = "boolean",
        x = "thread",
        u = "userdata",
        ["?"] = "nil"
    };

    ---Check that the parameter type signature conforms to the specification.
    ---@param sign  string   @The parameter type signature.
    ---@param last? boolean  @If or not it is the last parameter type signature.
    local CheckSign = function(sign,last)
        if "string" ~= type(sign) then
            error(i18n("The parameter type is not supported. - %s"):format(sign));
        end
        if sign == "..." then
            if not last then
                error(i18n"The '...' parameter must be at the end of the list.");
            end
        elseif sign ~= "*" then
            for j = 1,#sign do
                local char = sign:sub(j,j);
                if not signMap[char] then
                    error(i18n("The parameter type is not supported. - %s"):format(char));
                end
            end
        end
    end
    local retSign = setmetatable({},{
        __index = function(self,key)
            CheckSign(key);
            return self;
        end,
        __newindex = function (_,key,value)
            CheckSign(key,true);
            Done(nil,virtualKey,value);
        end
    });
    local function SimulationVirtualFunction(...)
        local args = {...};
        local len = #args;
        for i,sign in ipairs(args) do
            CheckSign(sign,i == len);
        end
        return retSign;
    end

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
    local AllMetaFunctions = Internal.ClassesAllMetaFunctions;
    local ClassesBanNew = Internal.ClassesBanNew;
    local ClassesBanDelete = Internal.ClassesBanDelete;

    local RouterReservedWord = Internal.RouterReservedWord;

    local p_const = Permission.const;
    local p_internalConstMethod = Internal.BitsMap.__InternalConstMethod;

    ---Wrapping metamethod.
    ---Because the invocation of metamethods does not depend on external lookups,
    ---it is not possible to determine the access permissons of metamethods directly.
    ---Therefore, only one more permission determination can be added to the invocation.
    ---@param wCls table
    ---@param f function
    ---@param const boolean
    ---@param key string
    ---@return function
    local function MetaFunctionWrapper(wCls,f,const,key)
        local metas = AllMetaFunctions[wCls];
        local newMF = metas[f];
        if nil == newMF then
            local newF = FunctionWrapper(wCls,f,nil,const);
            newMF = function(...)
                CheckPermission(wCls,key);
                return newF(...);
            end;
            metas[newMF] = newMF;
            metas[f] = newMF;
        end
        return newMF;
    end


    -- It is only under debug that the values need to be routed to the corresponding fields of the types.
    -- To save performance, all qualifiers will be ignored under non-debug.

    -- Rules:
    -- 1 - public/private/protected cannot be used together;
    -- 2 - static cannot qualify constructors and destructors;
    -- 3 - Can't use qualifiers that don't exist;
    -- 4 - Reserved words cannot be modified (__singleton/friends/handlers);
    -- 5 - (get/set) and (virtual/final) cannot be used together.
    Pass = function(self,key)
        local bit = BitsMap[key];
        if bit then
            decor = bor(decor,bit);
        else
            local isVirtual = band(decor,p_virtual) ~= 0;
            if isVirtual then
                virtualKey = key;
                return SimulationVirtualFunction;
            end
            local gs = band(decor,p_gs);
            if gs ~= 0 then
                local isGet = gs == p_get;
                CheckPermission(cls,(isGet and "g" or "s") .. key);
                local property = (gs == p_get and ClassesReadable or ClassesWritable)[cls][key];
                if property then
                    return property[1];
                end
            end
            error((i18n"There is no such qualifier. - %s"):format(key));
        end
        return self;
    end;

    Done = function(_,key,value)
        local isStatic = band(decor,p_static) ~= 0;
        local meta = MetaMapName[key];
        local gs = band(decor,p_gs);
        local isGet = gs == p_get;
        local disKey = key;
        if gs == 0 then
            if meta and isStatic then
                -- 'M' means the function is a static meta-method.
                -- Why do I need to distinguish static metamethods from normal metamethods?
                -- Similar to the distinction between static members and get/set methods,
                -- static metamethods can use the same name as normal metamethods and can take effect at the same time,
                -- without affecting each other.
                disKey = "M".. disKey;
            else
                -- 'n' means the function is a normal one.
                disKey = "n".. disKey;
            end
        else
            -- 'g' means the function is a getter.
            -- 's' means the function is a setter.
            disKey = (isGet and "g" or "s") .. disKey;
        end

        if FinalClassesMembers[cls][disKey] then
            error((i18n"You cannot define final members again. - %s"):format(key));
        end

        local isVirtual = band(decor,p_virtual) ~= 0;
        local vcp = VirtualClassesPermissons[cls];
        local vPermisson = vcp[disKey];
        if band(decor,p_override) ~= 0 then
            if isVirtual then
                error((i18n"%s,%s cannot be used at the same time."):format(override,virtual));
            elseif nil == vPermisson then
                error((i18n"Only pure virtual functions can be overridden. - %s"):format(key));
            end
            -- Strip the override and possible final properties,
            -- check if the remaining properties are get/set/0,
            -- and then check if they match the properties of the pure virtual function,
            -- otherwise, raise an error.
            local strippedDector = bor(decor - p_override,p_final) - p_final;
            if strippedDector == p_get or strippedDector == p_set or strippedDector == 0 then
                if band(strippedDector,vPermisson) ~= strippedDector then
                    error((i18n"A different access qualifier is used when you override pure virtual functions. - %s"):format(key));
                end
            else
                error((i18n"The %s function was overridden with an illegal qualifier."):format(key));
            end
            decor = bor(vPermisson,decor - p_override);
        end

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

        if isVirtual then
            if value ~= 0 then
                error((i18n"The pure virtual function %s must be assigned a value of 0."):format(key));
            elseif isStatic then
                error((i18n"The pure virtual function %s cannot be defined as a static function."):format(key));
            end
        end

        local bit = BitsMap[key] or RouterReservedWord[key];
        if bit then
            error((i18n"The name is unavailable. - %s"):format(key));
        end

        if isStatic and (key == ctor or key == dtor) then
            error((i18n"%s qualifier cannot qualify %s method."):format(static,key));
        end

        local vt = type(value);
        local isFunction = "function" == vt;

        if meta then
            if band(decor,p_gs) ~= 0 then
                error((i18n"You cannot qualify meta-methods with %s."):format(
                    get .. "," .. set
                ));
            elseif not isFunction then
                error((i18n"A function must be assigned to the meta-method. - %s"):format(key));
            end
        end

        if gs ~= 0 then
            if not isFunction and not isVirtual then
                error((i18n"A function must be assigned to the property %s."):format(key));
            elseif key == ctor or key == dtor then
                error((i18n"%s and %s can't be used as property."):format(ctor,dtor));
            end
        end

        if isGet and GetPropertyAutoConst then
            decor = bor(decor,p_const);
        end

        if isVirtual then
            local vcm = VirtualClassesMembers[cls];
            -- Always update the permission of the virtual function.
            local vp = bor(decor,p_virtual) - p_virtual;
            vcp[disKey] = vp;
            Update2ChildrenWithKey(cls,VirtualClassesPermissons,disKey,vp,true);
            if nil == vPermisson or nil ~= vcm[disKey] then
                -- But only update the member of virtual function if it is not nil,
                -- nil means that the virtual function is defined.
                vcm[disKey] = true;
                Update2ChildrenWithKey(cls,VirtualClassesMembers,disKey,true);
            end
            return;
        end

        if vPermisson then
            local vcm = VirtualClassesMembers[cls];
            -- Check pure virtual functions.
            if not isFunction then
                error((i18n"%s must be overridden as a function."):format(key));
            elseif bor(decor,p_final) - p_final ~= vPermisson then
                error((i18n"A different access qualifier is used when you override pure virtual functions. - %s"):format(key));
            end
            vcm[disKey] = nil;
            Update2ChildrenWithKey(cls,VirtualClassesMembers,disKey,nil,true);
        end

        local oVal = value;
        local pms = ClassesPermissions[cls];
        local isConst = band(decor,p_const) ~= 0;
        if isFunction then
            if meta and not band(decor,p_public) == 0 then
                -- Meta methods are wrapped with MetaFunctionWrapper functions only when they are not public.
                value = MetaFunctionWrapper(cls,value,isConst,disKey);
            else
                value = FunctionWrapper(cls,value,nil,isConst);
            end
            if isConst then
                -- Indicates that it is an internal const method.
                decor = bor(decor,p_internalConstMethod);
            end
        end

        if band(decor,p_final) ~= 0 then
            FinalClassesMembers[cls][disKey] = true;
            Update2ChildrenWithKey(cls,FinalClassesMembers,disKey,true);
        end

        if meta then
            if isStatic then
                local mt = getmetatable(cls);
                mt[meta] = value;
                Update2ChildrenClassMeta(cls,meta,value);
                pms[disKey] = decor;
            else
                local metas = ClassesMetas[cls];
                metas[meta] = value;
                Update2ChildrenWithKey(cls,ClassesMetas,meta,value);
            end
        else
            if gs ~= 0 or isStatic then
                local cms = ClassesMembers[cls];
                local cm = cms[key];
                if cm ~= nil then
                    cms[key] = nil;
                    Update2ChildrenWithKey(cls,ClassesMembers,key,nil,true);
                end
                if gs ~= 0 then
                    -- The property is set to a special table
                    -- with index 1 representing the function assigned to the property
                    -- and index 2 representing whether the property is a static property.
                    (isGet and ClassesReadable or ClassesWritable)[cls][key] = {value,isStatic};
                else
                    local cs = ClassesStatic[cls];
                    local st = cs[key];
                    if not st then
                        st = {value};
                        cs[key] = st;
                    else
                        st[1] = value;
                    end
                end
            else
                local cs = ClassesStatic[cls];
                cs[key] = nil;
                ClassesReadable[cls][key] = nil;
                ClassesWritable[cls][key] = nil;
                if isFunction then
                    ClassesAll[cls][key] = value;
                elseif "table" ~= vt or (not AllEnumerations[value] and not AllClasses[value]) then
                    -- For non-functional, non-static members,non-class objects,non-enumeration objects,
                    -- add to the member table and generate it for each instance.
                    ClassesMembers[cls][key] = value;
                    Update2ChildrenWithKey(cls,ClassesMembers,key,value);
                end

                if key == ctor then
                    -- Reassign permissions to "new", which are the same as ctor with the static qualifier.
                    pms[nNew] = bor(decor,p_static);
                    local ban = band(decor,p_private) ~= 0 or oVal == c_delete;
                    Update2Children(cls,ClassesBanNew,ban);
                elseif key == dtor then
                    pms[nDelete] = decor;
                    local ban = band(decor,p_private) ~= 0 or oVal == c_delete;
                    Update2Children(cls,ClassesBanDelete,ban);
                end
            end
        end
        pms[disKey] = decor;
    end;
else

    -- In Release mode, it is sufficient to use the empty implementation.
    local retSign = setmetatable({},{
        __index = function(self)
            return self;
        end,
        __newindex = function (_,_,value)
            Done(nil,virtualKey,value);
        end
    });
    local function SimulationVirtualFunction(...)
        return retSign;
    end

    -- In non-debug mode, no attention is paid to any qualifiers other than static.
    Pass = function(self,key)
        local bit = BitsMap[key];
        if bit then
            decor = bor(decor,bit);
        else
            local isVirtual = band(decor,p_virtual) ~= 0;
            if isVirtual then
                virtualKey = key;
                return SimulationVirtualFunction;
            end
            local get_set = band(decor,p_gs);
            if get_set ~= 0 then
                local property = (get_set == p_get and ClassesReadable or ClassesWritable)[cls][key];
                return property and property[1] or nil;
            end
        end
        return self;
    end;

    Done = function(_,key,value)
        if band(decor,p_virtual) ~= 0 then
            -- Skip pure virtual functions.
            return;
        end
        local isStatic = band(decor,p_static) ~= 0;
        local meta = MetaMapName[key];
        if meta then
            if isStatic then
                -- Meta methods are special and can only accept static qualifiers.
                local mt = getmetatable(cls);
                mt[meta] = value;
                Update2ChildrenClassMeta(cls,meta,value);
            else
                local metas = ClassesMetas[cls];
                metas[meta] = value;
                Update2ChildrenWithKey(cls,ClassesMetas,meta,value);
            end
            return;
        end

        local vt = type(value);
        local gs = band(decor,p_gs);

        if gs ~= 0 or isStatic then
            local cms = ClassesMembers[cls];
            local cm = cms[key];
            if cm ~= nil then
                cms[key] = nil;
                Update2ChildrenWithKey(cls,ClassesMembers,key,nil,true);
            end
            if gs ~= 0 then
                (gs == p_get and ClassesReadable or ClassesWritable)[cls][key] = {value,isStatic};
            else
                local cs = ClassesStatic[cls];
                local st = cs[key];
                if not st then
                    st = {value};
                    cs[key] = st;
                else
                    st[1] = value;
                end
            end
        else
            local isFunction = "function" == vt;
            ClassesStatic[cls][key] = nil;
            ClassesReadable[cls][key] = nil;
            ClassesWritable[cls][key] = nil;
            if isFunction then
                rawset(cls,key,value);
            elseif "table" ~= vt or (not AllEnumerations[value] and not AllClasses[value]) then
                ClassesMembers[cls][key] = value;
                Update2ChildrenWithKey(cls,ClassesMembers,key,value);
            end
        end
    end;
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