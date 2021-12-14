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

local setmetatable = setmetatable;
local getmetatable = getmetatable;
local warn = warn or print;
local pairs = pairs;
local ipairs = ipairs;
local type = type;
local select = select;
local error = error;
local Internal = require("OOP.Variant.Internal");
local Config = require("OOP.Config");
local BaseFunctions = require("OOP.BaseFunctions");
local i18n = require("OOP.i18n");
local Meta = Config.Meta;
local AllStructs = Internal.AllStructs;
local StructsMembers = Internal.ClassesMembers;
local Copy = BaseFunctions.Copy;
local ctor = Config.ctor;
local struct = Config.struct;
local Debug = Config.Debug;

local function StructBuild(bases)
    return function (proto)
        if Debug and type(proto) ~= "table" then
            error(i18n"The structure must be declared as a table.");
        end
        if nil ~= getmetatable(proto) then
            warn(i18n"Struct be used on a table with metatable.");
        end
        -- Member table containing only the fields of non-function and non-meta methods.
        -- And these fields are not changed after initialization.
        local members = setmetatable({},{
            __index = function (_,key)
                for _,base in ipairs(bases) do
                    local ret = StructsMembers[base][key];
                    if nil ~= ret then
                        return ret;
                    end
                end
            end
        });
        StructsMembers[proto] = members;
        AllStructs[proto] = true;

        -- 1.Here all "members" are assigned only from the inherited structure.
        for _,base in ipairs(bases) do
            local baseMembers = StructsMembers[base];
            for k,v in pairs(baseMembers) do
                members[k] = v;
            end
        end

        -- 2.Moves non-meta methods and non-function fields from the prototype to members.
        for k,v in pairs(proto) do
            if not Meta[k] and type(v) ~= "function" then
                members[k] = v;
                proto[k] = nil;
            end
        end

        -- 3.Assign the inherited value to the current structure.
        -- Note:
        -- Do not combine this step with step 1 because some fields may be delayed declarations
        -- and the members of the structure do not contain delayed declarations of the fields.
        for _,base in ipairs(bases) do
            for k,v in pairs(base) do
                if nil == proto[k] then
                    proto[k] = v;
                end
            end
        end

        proto.__index = proto;
        return setmetatable(proto,{
            __index = function (_,k)
                local ret = members[k];
                if ret ~= nil then
                    return ret;
                end
                for _,base in ipairs(bases) do
                    ret = base[k];
                    if ret ~= nil then
                        return ret;
                    end
                end
            end,
            __call = function (_,...)
                local sObj = setmetatable(Copy(members),proto);
                local _ctor = proto[ctor];
                if _ctor then
                    _ctor(sObj, ...);
                end
                return sObj;
            end
        });
    end;
end

_G[struct] = function(...)
    local len = select("#",...);
    if len == 1 and nil == AllStructs[...] then
        return StructBuild({})(...);
    end
    local bases = {...};
    if Debug then
        for _,v in ipairs(bases) do
            if not AllStructs[v] then
                error(i18n"The base structure is not a struct type.");
            end
        end
    end
    return StructBuild(bases);
end;