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

local Debug = require("OOP.Config").Debug;
local WeakTable = {__mode = "k"};
return {
    AllClasses = {},
    ClassesReadable = setmetatable({},WeakTable),
    ClassesWritable = setmetatable({},WeakTable),
    ClassesHandlers = setmetatable({},WeakTable),
    ClassesBases = setmetatable({},WeakTable),
    ClassesMembers = setmetatable({},WeakTable),
    ClassesMetas = setmetatable({},WeakTable),
    ClassesCreate = setmetatable({},WeakTable),
    -- Represents the c++ base class of the class (and also the only c++ base class).
    ClassesCppBase = setmetatable({},WeakTable),
    -- function constructor in the index of the inheritance list, once the type has been constructed once,
    -- this field will be invalidated.
    ClassesCtorIndex = setmetatable({},WeakTable),
    ClassesSingleton = setmetatable({},WeakTable),
    ObjectsAll = setmetatable({},WeakTable),
    ObjectsCls = setmetatable({},WeakTable),
    ClassesAll = setmetatable({},WeakTable);
    ClassesPermisssions = Debug and setmetatable({},WeakTable) or nil,
    ClassesFriends = Debug and setmetatable({},WeakTable) or nil,
    AccessStack = Debug and {} or nil
};