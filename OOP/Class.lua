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
local type = type;
local pcall = pcall;
local error = error;

local Config = require("OOP.Config");
local Debug = Config.Debug;
local ctor = Config.ctor;

local Functions = Debug and require("OOP.Variant.DebugFunctions") or require("OOP.Variant.BaseFunctions");
local ClassesBases = Functions.ClassesBases;
local CreateClassObject = Functions.CreateClassObject;
local class = Functions.class;
local CreateClassTables = Functions.CreateClassTables;
local CheckClassName = Functions.CheckClassName;
local ClassInherite = Functions.ClassInherite;
local CreateClassIs = Functions.CreateClassIs;
local CreateClassDelete = Functions.CreateClassDelete;
local FinishUserDataObject = Functions.FinishUserDataObject;
local RegisterHandlersAndMembers = Functions.RegisterHandlersAndMembers;
local AttachClassFunctions = Functions.AttachClassFunctions;
local MakeTableObjectMeta = Functions.MakeTableObjectMeta;
local ClassesBanNew = Functions.ClassesBanNew;

local ClassMeta = {
    __index = Functions.ClassGet,
    __newindex = Functions.ClassSet
};
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
            assert(not ClassesBanNew[cls],"The base classes constructor is not accessible.");
        end
        ClassCreateLayer = ClassCreateLayer + 1;
        local obj,all = CreateClassObject(cls,...);
        if nil == obj then
            ClassCreateLayer = ClassCreateLayer - 1;
            return nil;
        end

        if ClassCreateLayer == 1 then
            RegisterHandlersAndMembers(obj,all,handlers,members);

            if "table" == type(obj) then
                setmetatable(obj,MakeTableObjectMeta(cls));
            else
                FinishUserDataObject(obj,cls);
            end
        end

        ObjectInit(obj,cls,clsAll,...);
        return obj;
    end;
end

function class.New(...)
    local cls,all,bases,handlers,members,metas = CreateClassTables();

    local args = {...};
    CheckClassName(cls,args);
    ClassInherite(cls,args,bases,handlers,members,metas);

    local _is = CreateClassIs(cls,bases);
    local _new = CreateClassNew(cls,all,handlers,members);
    local _delete = CreateClassDelete(cls);

    AttachClassFunctions(cls,_is,_new,_delete);

    return setmetatable(cls,ClassMeta);
end