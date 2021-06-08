-- Copyright (c) 2021 榆柳松

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
local Debug = Config.Debug;

local new = Config.new;

local Public = Config.Modifiers.Public;
local Private = Config.Modifiers.Private;
local Protected = Config.Modifiers.Protected;
local Static = Config.Modifiers.Static;
local Const = Config.Modifiers.Const;

local BitsMap = {
    [Public] = 1,
    [Private] = 2,
    [Protected] = 4,
    [Static] = 8,
    [Const] = 16
};
local Permission = {
    Public = BitsMap[Public],
    Private = BitsMap[Private],
    Protected = BitsMap[Protected],
    Static = BitsMap[Static],
    Const = BitsMap[Const]
}
local Router = nil;

if Debug then
    Router = {};
    local Handlers = Config.Handlers;
    local Properties = Config.Properties;
    local Friends = Config.Friends;
    local Singleton = Config.Singleton;

    local __init__ = Config.__init__;
    local __del__ = Config.__del__;

    local __all__ = Config.__all__;
    local __pm__ = Config.__pm__;

    local bits = require("OOP.Version.Compat").bits;
    -- It is only under debug that the values need to be routed to the corresponding fields of the types.
    -- To save performance, all modifiers will be ignored under non-debug.

    -- Rules:
    -- 1 - There can be no duplicate modifiers;
    -- 2 - Public/Private/Protected cannot be used together;
    -- 3 - Const can only modify non-function types;
    -- 4 - Static can only modify functions(because the class members are static by default);
    -- 5 - Static cannot modify constructors and destructors;
    -- 6 - Can't use modifiers that don't exist;
    -- 7 - Reserved words cannot be modified (Singleton/Friends/Handlers/Properties and so on).
    function Router:Begin(cls,key)
        rawset(self,"decor",0);
        rawset(self,"cls",cls);
        return self:Pass(key);
    end
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
        local cls = self.cls;
        if nil == value then
            cls[__all__][key] = nil;
            cls[__pm__][key] = nil;
            return;
        end
        local decor = self.decor;
        local isFunction = "function" == type(value);
        if (bits.band(decor,Permission.Const) ~= 0 and isFunction) then
            error(("%s modifier cannot modify %s functions."):format(Const,key));
        elseif bits.band(decor,Permission.Static) ~= 0 then
            if (key == __init__ or key == __del__) then
                error(("%s modifier cannot modify %s functions."):format(Static,key));
            elseif not isFunction then
                error(("%s can only modify functions."):format(Static));
            end
        elseif key == Handlers or key == Properties or key == Singleton or key == Friends then
            error(("%s cannot be modified."):format(key));
        end
        if bits.band(decor,0x7) == 0 then
            -- Without the Public modifier, Public is added by default.
            decor = bits.bor(decor,0x1);
        end
        cls[__all__][key] = value;
        cls[__pm__][key] = decor;
        if key == __init__ and bits.band(decor,0x1) ~= 1 then
            -- Reassign permissions to "new", which are the same as __init__ with the Static modifier.
            cls[__pm__][new] = bits.bor(decor,0x8);
        end
        self.decor = 0;
        self.cls = nil;
    end
    setmetatable(Router,{
        __index = function (self,key)
            return self:Pass(key);
        end,
        __newindex = function (self,key,val)
            self:End(key,val);
        end
    });
end

return {
    Router = Router,
    BitsMap = BitsMap,
    Permission = Permission
};