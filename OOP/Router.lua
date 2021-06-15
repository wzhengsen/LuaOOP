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
local Config = require("OOP.Config");
local Version = Config.Version;
local Internal = require("OOP.Variant.Internal");
local ClassesMembers = Internal.ClassesMembers;

local Compat = require("OOP.Version.Compat");
local bits = Compat.bits;
local Debug = Config.Debug;

local MetaMapName = Config.MetaMapName;

local new = Config.new;

local Public = Config.Modifiers.Public;
local Private = Config.Modifiers.Private;
local Protected = Config.Modifiers.Protected;
local Static = Config.Modifiers.Static;
local Const = Config.Modifiers.Const;

local BitsMap = {
    [Public] = 2 ^ 0,
    [Private] = 2 ^ 1,
    [Protected] = 2 ^ 2,
    [Static] = 2 ^ 3,
    [Const] = 2 ^ 4
};
if Version > 5.2 then
    BitsMap.Public = math.tointeger(BitsMap.Public);
    BitsMap.Private = math.tointeger(BitsMap.Private);
    BitsMap.Protected = math.tointeger(BitsMap.Protected);
    BitsMap.Static = math.tointeger(BitsMap.Static);
    BitsMap.Const = math.tointeger(BitsMap.Const);
end
local Permission = {
    Public = BitsMap[Public],
    Private = BitsMap[Private],
    Protected = BitsMap[Protected],
    Static = BitsMap[Static],
    Const = BitsMap[Const]
}
local Router = {};

function Router:Begin(cls,key)
    rawset(self,"decor",0);
    rawset(self,"cls",cls);
    return self:Pass(key);
end

if Debug then
    local Handlers = Config.Handlers;
    local Properties = Config.Properties;
    local Friends = Config.Friends;
    local Singleton = Config.Singleton;

    local __init__ = Config.__init__;
    local __del__ = Config.__del__;



    local FunctionWrapper = Compat.FunctionWrapper;
    local AccessStack = Internal.AccessStack;
    local ClassesAll = Internal.ClassesAll;
    local ClassesPermisssions = Internal.ClassesPermisssions;
    -- It is only under debug that the values need to be routed to the corresponding fields of the types.
    -- To save performance, all modifiers will be ignored under non-debug.

    -- Rules:
    -- 1 - There can be no duplicate modifiers;
    -- 2 - Public/Private/Protected cannot be used together;
    -- 3 - Static cannot modify constructors and destructors;
    -- 4 - Can't use modifiers that don't exist;
    -- 5 - Reserved words cannot be modified (Singleton/Friends/Handlers/Properties and so on).
    function Router:Pass(key)
        local bit = BitsMap[key];
        local decor = self.decor;
        if bit then
            if bits.band(decor,bit) ~= 0 then
                error(("The %s modifier is not reusable."):format(key));
            elseif bits.band(decor,0x7) ~= 0 and bits.band(bit,0x7) ~= 0 then
                -- Check Public,Private,Protected,they are 0x7
                error(("The %s modifier cannot be used in conjunction with other access modifiers."):format(key));
            end
            self.decor = bits.bor(decor,bit);
        else
            error(("There is no such modifier. - %s"):format(key));
        end
        return self;
    end
    function Router:End(key,value)
        local bit = BitsMap[key];
        if bit then
            error(("The name is unavailable. - %s"):format(key));
        end
        local meta = MetaMapName[key];
        if meta then
            error(("You cannot modify meta-methods. - %s"):format(key));
        end
        local decor = self.decor;
        local isFunction = "function" == type(value);
        if bits.band(decor,Permission.Static) ~= 0 then
            if (key == __init__ or key == __del__) then
                error(("%s modifier cannot modify %s functions."):format(Static,key));
            end
        elseif key == Handlers or key == Properties or key == Singleton or key == Friends then
            error(("%s cannot be modified."):format(key));
        end
        if bits.band(decor,0x7) == 0 then
            -- Without the Public modifier, Public is added by default.
            decor = bits.bor(decor,0x1);
        end
        local cls = self.cls;
        if isFunction then
            value = FunctionWrapper(AccessStack,cls,value);
        else
            -- For non-functional, non-static members,
            -- add to the member table and generate it for each instance.
            if bits.band(decor,Permission.Static) == 0 then
                ClassesMembers[cls][key] = value;
            end
        end
        ClassesAll[cls][key] = value;
        local pms = ClassesPermisssions[cls];
        pms[key] = decor;
        if key == __init__ then
            -- Reassign permissions to "new", which are the same as __init__ with the Static modifier.
            pms[new] = bits.bor(decor,0x8);
        end
        self.decor = 0;
        self.cls = nil;
    end
else
    local ClassesMetas = Internal.ClassesMetas;
    local sc = Permission.Static;
    -- In non-debug mode, no attention is paid to any modifiers other than Static.
    function Router:Pass(key)
        if BitsMap[key] == sc then
            self.decor = sc;
        end
        return self;
    end
    function Router:End(key,value)
        local cls = self.cls;
        if "function" ~= type(value) and self.decor ~= sc then
            ClassesMembers[cls][key] = value;
        end
        rawset(cls,key,value);
        self.decor = 0;
        self.cls = nil;

        local meta = MetaMapName[key];
        if meta then
            local metas = ClassesMetas[cls];
            metas[key] = value;
        end
    end
end

setmetatable(Router,{
    __index = function (self,key)
        return self:Pass(key);
    end,
    __newindex = function (self,key,val)
        self:End(key,val);
    end
});

return {
    Router = Router,
    BitsMap = BitsMap,
    Permission = Permission
};