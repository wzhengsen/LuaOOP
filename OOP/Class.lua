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
local type = type;
local pcall = pcall;
local error = error;
local next = next;
local select = select;
local d_setmetatable = debug.setmetatable;
local rawget = rawget;

local Config = require("OOP.Config");
local Debug = Config.Debug;
local ctor = Config.ctor;
local raw = Config.raw;
local del = Config.del;

local i18n = require("OOP.i18n");
local Internal = require("OOP.Variant.Internal");

local Functions = Debug and require("OOP.Variant.DebugFunctions") or require("OOP.Variant.ReleaseFunctions");
local ClassesBases = Functions.ClassesBases;
local CreateClassObject = Functions.CreateClassObject;
local class = Functions.class;
local CreateClassTables = Functions.CreateClassTables;
local CheckClass = Functions.CheckClass;
local ClassInherite = Functions.ClassInherite;
local CreateClassIs = Functions.CreateClassIs;
local CreateClassDelete = Functions.CreateClassDelete;
local RetrofitExternalObjectMeta = Functions.RetrofitExternalObjectMeta;
local MakeInternalObjectMeta = Functions.MakeInternalObjectMeta;
local RegisterHandlersAndMembers = Functions.RegisterHandlersAndMembers;
local AttachClassFunctions = Functions.AttachClassFunctions;
local ClassesBanNew = Functions.ClassesBanNew;
local ClassesMetas = Functions.ClassesMetas;
local VirtualClassesMembers = Functions.VirtualClassesMembers;
local ObjectsCls = Internal.ObjectsCls;
local NamedClasses = Internal.NamedClasses;
local AllClasses = Internal.AllClasses;
local ObjectsAll = Internal.ObjectsAll;
local __internal__ = Config.__internal__;
local to = Config.to;


local ClassCreateLayer = 0;
local function ObjectInit(obj,cls,all,...)
    -- When there is no constructor of its own, if there are less than 2 base classes,
    -- the constructor is automatically found.
    local init = all[ctor] or (#ClassesBases[cls] == 1 and cls[ctor] or nil);
    -- Do not get ctor from ClassesAll and make it search automatically.
    if init then
        -- Avoid recursively polluting the classCreateLayer variable when create a new object in the ctor.
        -- Cache it, after the call, set it to classCreateLayer+tempCreateLayer
        -- The final call ends with the value -1.
        local tempCreateLayer = ClassCreateLayer;
        ClassCreateLayer = 0;
        local ok,msg = pcall(init,obj,...);
        ClassCreateLayer = ClassCreateLayer + tempCreateLayer - 1;
        if not ok then
            error(msg);
        end
    else
        ClassCreateLayer = ClassCreateLayer - 1;
    end
end

local function CreateClassNew(cls,clsAll,handlers,members)
    return function(...)
        if Debug then
            if ClassesBanNew[cls] then
                error(i18n "The class/base classes constructor is not accessible.");
            end
            local key = next(VirtualClassesMembers[cls]);
            if nil ~= key then
                error((i18n"Cannot construct class with unoverridden pure virtual functions. - %s"):format(key:sub(2)));
            end
        end
        ClassCreateLayer = ClassCreateLayer + 1;
        local ok,obj,all = pcall(CreateClassObject,cls,...);
        if not ok or nil == obj then
            if obj then
                print(i18n"An error occurred when creating the object -",obj);
            end
            ClassCreateLayer = ClassCreateLayer - 1;
            if not ok then
                error(obj);
            end
            return nil;
        end

        if ClassCreateLayer == 1 then
            RegisterHandlersAndMembers(obj,all,handlers,members);
            local metas = getmetatable(obj);
            if not metas or rawget(metas,__internal__) then
                -- If the object does not have a meta table or if the meta table is internal to LuaOOP,
                -- then it is sufficient to use that meta table directly.
                d_setmetatable(obj,ClassesMetas[cls]);
            else
                -- Otherwise, the meta-table is retrofited.
                ObjectsCls[obj] = cls;
                RetrofitExternalObjectMeta(cls,metas,false);
            end
            ObjectInit(obj,cls,clsAll,...);
        else
            ClassCreateLayer = ClassCreateLayer - 1;
        end

        return obj;
    end;
end

---Create a class, passing in parameters to inherit from other classes.
---
---@vararg string|table
---@return table @class
function class.new(...)
    local args = {...};
    if Debug then
        local len = 0;
        while nil ~= args[len + 1] do
            len = len + 1;
        end
        if select("#", ...) ~= len then
            error(i18n "You cannot inherit a nil value.");
        end
    end

    local cls,metas,name = CheckClass(args);
    if rawget(metas,__internal__) then
        MakeInternalObjectMeta(cls,metas);
    else
        -- The third parameter true indicates that this meta-table was created externally
        -- and that it is forced to transform this meta-table.
        -- That is, the difference between the SOL class and the FILE* class is.
        -- 1. the use of names to force the retrofitting of the SOL class (true).
        -- 2. the use of a table to inherit the FILE* class (false).
        RetrofitExternalObjectMeta(cls,metas,true);
    end

    local all,bases,handlers,members = CreateClassTables(cls);

    local clsMeta = {};
    setmetatable(cls,clsMeta);

    ClassInherite(cls,args,bases,handlers,members,ClassesMetas[cls],name);

    AttachClassFunctions(
        cls,
        CreateClassIs(cls,bases),
        CreateClassNew(cls,all,handlers,members),
        CreateClassDelete(cls)
    );

    clsMeta.__index = Functions.ClassGet;
    clsMeta.__newindex = Functions.ClassSet;
    return cls;
end

if Debug then
    local BreakFunctionWrapper = require("OOP.BaseFunctions").BreakFunctionWrapper;
    class[raw] = function(first, second, third)
        if nil == third then
            if nil == second then
                if "function" ~= type(first) then
                    error((i18n "%s must wrap a function."):format(raw));
                end
                return BreakFunctionWrapper(first);
            else
                return BreakFunctionWrapper(function() return first[second]; end)();
            end
        else
            BreakFunctionWrapper(function() first[second] = third; end)();
        end
    end;
    class[to] = function (obj,cls)
        local t = type(cls);
        if t == "string" then
            cls = NamedClasses[cls];
        elseif t == "table" then
            if not AllClasses[cls] then
                cls = nil;
            end
        end
        if nil == cls then
            error(i18n"A non-existent class is used.");
        end
        local metas = getmetatable(obj);
        if not metas or rawget(metas,__internal__) then
            d_setmetatable(obj,ClassesMetas[cls]);
        else
            RetrofitExternalObjectMeta(cls,metas,false);
            ObjectsCls[obj] = cls;
        end
        if not ObjectsAll[obj] then
            ObjectsAll[obj] = {};
        end
        return obj;
    end;
else
    class[raw] = function(first, second, third)
        if nil == third then
            if nil == second then
                return first;
            else
                return first[second];
            end
        else
            first[second] = third;
        end
    end;
    class[to] = function (obj,cls)
        local t = type(cls);
        if t == "string" then
            cls = NamedClasses[cls];
        elseif t == "table" then
            if not AllClasses[cls] then
                cls = nil;
            end
        end
        if nil == cls then
            return obj;
        end
        local metas = getmetatable(obj);
        if not metas or rawget(metas,__internal__) then
            d_setmetatable(obj,ClassesMetas[cls]);
        else
            RetrofitExternalObjectMeta(cls,metas,false);
            ObjectsCls[obj] = cls;
        end
        if type(obj) == "userdata" and not ObjectsAll[obj] then
            ObjectsAll[obj] = {};
        end
        return obj;
    end;
end

class[del] = Functions.CallDel;
