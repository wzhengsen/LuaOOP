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

local type = type;
local setmetatable = setmetatable;

require("OOP.Enum");
require("OOP.Struct");
local Config = require("OOP.Config");
local Internal = require("OOP.Variant.Internal");
local Debug = Config.Debug;
local Null = Config.ExternalClass.Null;
local null = Config.null;
local final = Config.Qualifiers.final;
local FinalClasses = Internal.FinalClasses;
local DeathMark = Internal.DeathMark;
local ClassDefault = Config["class.default"];
local ClassDelete = Config["class.delete"];
local i18n = require("OOP.i18n");

local class = setmetatable({},{
    __call = function(c,...)
        return c.new(...)
    end
});
rawset(_G,Config.class,class);

local _null = Null and function(t)
    local tt = type(t);
    if tt == "table" then
        return DeathMark[t] == true;
    elseif tt == "userdata" then
        return Null(t);
    end
    return not t;
end or
function(t)
    local tt = type(t);
    if tt == "table" or tt == "userdata" then
        return DeathMark[t] == true;
    end
    return not t;
end;
class[null] = _null;

if Debug then
    class[final] = function (...)
        if type((...)) == "string" then
            FinalClasses[(...)] = true;
        end
        local cls = class.new(...);
        FinalClasses[cls] = true;
        return cls;
    end;
else
    class[final] = function (...)
        return class.new(...);
    end;
end

class[ClassDefault] = function ()end;
class[ClassDelete] = function () error(i18n"This is the function that has been deleted.");end;
class.Version = Config.Version;

return class;