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

local Config = require("OOP.Config");

local require = require;
local rawset = rawset;
local type = type;
local select = select;
local warn = warn or print;
local mType = Config.LuaVersion > 5.2 and math.type or type;
local integer = Config.LuaVersion > 5.2 and "integer" or "number";

local i18n = require("OOP.i18n");
local EnumBehavior = Config.EnumBehavior;
local DefaultEnumIndex = Config.DefaultEnumIndex;
local AllEnumerations = require("OOP.Variant.Internal").AllEnumerations;
local enum = nil;
local auto = DefaultEnumIndex - 1;

if Config.Debug then
    function enum(first,...)
        if nil == first then
            auto = auto + 1;
            return auto;
        end
        local isInteger = mType(first) == integer;
        if isInteger then
            auto = first;
            return auto;
        end
        auto = DefaultEnumIndex - 1;
        local fT = type(first);
        local isString = fT == "string";
        if not (isString or fT == "table") then
            error(i18n "Only integers or strings or tables can be used to generate a enumeration.");
        end
        if not isString and select("#", ...) ~= 0 then
            error(i18n "Excess parameters.");
        end
        local e = isString and {} or first;
        if isString then
            for k,v in ipairs({first,...}) do
                e[v] = k;
            end
        end

        if EnumBehavior == 2 then
            AllEnumerations[e] = true;
            return e;
        end

        local _enum = {};
        AllEnumerations[_enum] = true;
        return setmetatable(_enum,{
            __index = e,
            __newindex = function ()
                if EnumBehavior == 0 then
                    warn("You can't edit a enumeration.");
                elseif EnumBehavior == 1 then
                    error(i18n"You can't edit a enumeration.");
                end
            end,
            __pairs = function()return pairs(e);end
        });
    end
else
    function enum(first,...)
        if nil == first then
            auto = auto + 1;
            return auto;
        end
        local isInteger = mType(first) == integer;
        if isInteger then
            auto = first;
            return auto;
        end
        auto = DefaultEnumIndex - 1;
        local isString = type(first) == "string"
        local e = isString and {} or first;
        if isString then
            for k,v in ipairs({first,...}) do
                e[v] = k;
            end
        end
        AllEnumerations[e] = true;
        return e;
    end
end
rawset(_G,Config.enum,enum);