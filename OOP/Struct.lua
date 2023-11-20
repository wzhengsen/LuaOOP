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
local warn = warn;
local pairs = pairs;
local ipairs = ipairs;
local type = type;
local select = select;
local error = error;
local rawset = rawset;
local rawget = rawget;
local Internal = require("OOP.Variant.Internal");
local Config = require("OOP.Config");
local BaseFunctions = require("OOP.BaseFunctions");
local i18n = require("OOP.i18n");
local Meta = Config.Meta;
local AllStructs = Internal.AllStructs;
local StructsMembers = Internal.ClassesMembers;
local StructsDelays = Internal.ClassesStatic;
local StructsBases = Internal.ClassesBases;
local Copy = BaseFunctions.Copy;
local ctor = Config.ctor;
local struct = Config.struct;
local Debug = Config.Debug;
local to = Config["struct.to"];
local structFuncName = Config["struct.struct"];
local object = Config["struct.object"];
local StructBehavior = Config.StructBehavior;

local function MetaCascadeGet(bases,tab)
    return {
        __index = function(_, k)
            for _,base in ipairs(bases) do
                local ret = tab[base][k];
                if nil ~= ret then
                    return ret;
                end
            end
        end
    };
end

local function CascadeRawGet(proto,key)
    local members = StructsMembers[proto];
    local ret = members[key];
    if nil ~= ret then
        return ret;
    end
    ret = rawget(proto,key);
    if nil ~= ret then
        return ret;
    end
    local bases = StructsBases[proto];
    for _,base in ipairs(bases) do
        ret = CascadeRawGet(base,key);
        if nil ~= ret then
            return ret;
        end
    end
end

local ProtoNewIndexMeta = nil;
if Debug then
    if StructBehavior == 0 then
        ProtoNewIndexMeta = function(obj,key,value)
            local m = StructsMembers[getmetatable(obj)];
            if m[key] == nil then
                warn(i18n"You are attempting to add a field to the struct.");
            end
            rawset(obj,key,value);
        end;
    elseif StructBehavior == 1 then
        ProtoNewIndexMeta = function(obj,key,value)
            local m = StructsMembers[getmetatable(obj)];
            if m[key] == nil then
                error(i18n"You are attempting to add a field to the struct and that behavior is prohibited.");
            end
            rawset(obj,key,value);
        end;
    elseif StructBehavior ~= 2 then
        ProtoNewIndexMeta = function(obj,key,value)
            local m = StructsMembers[getmetatable(obj)];
            if m[key] == nil then
                return;
            end
            rawset(obj,key,value);
        end;
    end
end

local function StructBuild(bases)
    return function(proto)
        if Debug and type(proto) ~= "table" then
            error(i18n "The structure must be declared as a table.");
        end
        if nil ~= getmetatable(proto) then
            warn(i18n "Struct be used on a table with metatable.");
        end
        -- Member table containing only the fields of non-function and non-meta methods.
        -- And these fields are not changed after initialization.
        local members = setmetatable({}, MetaCascadeGet(bases, StructsMembers));
        local delays = setmetatable({}, MetaCascadeGet(bases, StructsDelays));
        StructsMembers[proto] = members;
        StructsDelays[proto] = delays;
        StructsBases[proto] = bases;
        AllStructs[proto] = true;


        -- 1.Here all "members" are assigned only from the inherited structure.
        for _, base in ipairs(bases) do
            local baseMembers = StructsMembers[base];
            for k, v in pairs(baseMembers) do
                members[k] = v;
            end
        end

        -- 2.Moves non-meta methods and non-function fields from the prototype to members.
        for k, v in pairs(proto) do
            if not Meta[k] and type(v) ~= "function" then
                members[k] = v;
                proto[k] = nil;
            end
        end

        -- 3.Assign the inherited value to the current structure.
        -- Note:
        -- Do not combine this step with step 1 because some fields may be delayed declarations
        -- and the members of the structure do not contain delayed declarations of the fields.
        for _, base in ipairs(bases) do
            for k, v in pairs(base) do
                if nil == proto[k] then
                    proto[k] = v;
                end
            end
        end

        proto.__index = function(_, k)
            return CascadeRawGet(proto, k);
        end;
        proto.__newindex = ProtoNewIndexMeta;
        return setmetatable(proto, {
            __index = function(_, k)
                local ret = members[k];
                if ret ~= nil then
                    return ret;
                end
                ret = delays[k];
                if ret ~= nil then
                    return ret;
                end
                for _, base in ipairs(bases) do
                    ret = base[k];
                    if ret ~= nil then
                        return ret;
                    end
                end
            end,
            __newindex = function(_, k, v)
                if Meta[k] or type(v) == "function" then
                    rawset(proto, k, v);
                else
                    delays[k] = v;
                end
            end,
            __call = function(_, ...)
                local sObj = setmetatable(Copy(members), proto);
                local _ctor = proto[ctor];
                if _ctor then
                    _ctor(sObj, ...);
                end
                return sObj;
            end
        });
    end;
end

local struct__ = setmetatable({}, {
    __call = function (_,...)
        local len = select("#", ...);
        if len == 1 and nil == AllStructs[(...)] then
            return StructBuild({})(...);
        end
        local bases = { ... };
        if Debug then
            for _, v in ipairs(bases) do
                if not AllStructs[v] then
                    error(i18n "The base structure is not a struct type.");
                end
            end
        end
        return StructBuild(bases);
    end;
});

struct__[object] = function(obj)
    if type(obj) == "table" then
        return AllStructs[getmetatable(obj)] ~= nil;
    end
end;

struct__[structFuncName] = function(st)
    return AllStructs[st] ~= nil;
end;

struct__[to] = function(obj, st)
    return setmetatable(obj, st);
end;

_G[struct] = struct__;