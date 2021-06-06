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
local bit32 = require("OOP.Compat.LowerThan53").bit32;
local Debug = Config.Debug;

local Public = Config.Modifiers.Public;
local Private = Config.Modifiers.Private;
local Protected = Config.Modifiers.Protected;
local Static = Config.Modifiers.Static;
local Const = Config.Modifiers.Const;

local BitsMap = {
    [Public] = 1 << 0,
    [Private] = 1 << 1,
    [Protected] = 1 << 2,
    [Static] = 1 << 3,
    [Const] = 1 << 4
};
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
    -- It is only under debug that the values need to be routed to the corresponding fields of the types.
    -- To save performance, all modifiers will be ignored under non-debug.
    function Router:Begin(cls,key)
        rawset(self,"decor",0);
        rawset(self,"cls",cls);
        return self:Pass(key);
    end
    function Router:Pass(key)
        local bit = BitsMap[key];
        local decor = self.decor;
        if bit then
            if decor & bit ~= 0 then
                error(("The %s modifier is not reusable."):format(key));
            elseif decor & 0x7 ~= 0 and bit & 0x7 ~= 0 then
                -- Check Public,Private,Protected,they are 0x7
                error(("The %s modifier cannot be used in conjunction with other access modifiers."):format(key));
            end
            self.decor = decor | bit;
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
        local decor = self.decor;
        if (decor & BitsMap[Static] ~= 0) and
        (key == __init__ or key == __del__) then
            error(("%s modifier cannot modify %s functions."):format(Static,key));
        elseif key == Handlers or key == Properties or key == Singleton or key == Friends then
            error(("%s cannot be modified."):format(key));
        end
        local cls = self.cls;
        cls[__all__][key] = value;
        cls[__pm__][key] = decor;
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
    Permission = {
        Public = BitsMap[Public],
        Private = BitsMap[Private],
        Static = BitsMap[Static],
        Const = BitsMap[Const]
    }
};