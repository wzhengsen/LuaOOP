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
local Config = require("OOP.Config");
local Debug = Config.Debug;
local WeakTable = {__mode = "k"};

local public = Config.Qualifiers.public;
local private = Config.Qualifiers.private;
local protected = Config.Qualifiers.protected;
local static = Config.Qualifiers.static;
local const = Config.Qualifiers.const;
local final = Config.Qualifiers.final;
local virtual = Config.Qualifiers.virtual;
local override = Config.Qualifiers.override;
local mutable = Config.Qualifiers.mutable;
local get = Config.get;
local set = Config.set;

local BitsMap = {
    [public] = 1 << 0,
    [private] = 1 << 1,
    [protected] = 1 << 2,
    [static] = 1 << 3,
    [const] = 1 << 4,
    [final] = 1 << 5,
    [get] = 1 << 6,
    [set] = 1 << 7,
    [virtual] = 1 << 8,
    [override] = 1 << 9,
    [mutable] = 1 << 10
};

local max = nil;
for _, v in pairs(BitsMap) do
    if max == nil or max < v then
        max = v;
    end
end
-- Used to instruct const methods internally,
-- external code doesn't need to care about this.
-- Ensure that the value does not exist in the BitsMap.
local __InternalConstMethod = max << 2;

local Permission = {
    public = BitsMap[public],
    private = BitsMap[private],
    protected = BitsMap[protected],
    static = BitsMap[static],
    const = BitsMap[const],
    final = BitsMap[final],
    get = BitsMap[get],
    set = BitsMap[set],
    virtual = BitsMap[virtual],
    override = BitsMap[override],
    mutable = BitsMap[mutable]
};

return {
    NamedClasses = {},
    ClassesChildrenByName = {},
    DeathMark = setmetatable({},WeakTable),
    AllClasses = setmetatable({},WeakTable),
    AllStructs = setmetatable({},WeakTable),
    AllEnumerations = setmetatable({},WeakTable),
    ClassesReadable = setmetatable({},WeakTable),
    ClassesWritable = setmetatable({},WeakTable),
    ClassesHandlers = setmetatable({},WeakTable),
    ClassesBases = setmetatable({},WeakTable),
    -- Record which classes inherit from this class.
    ClassesChildren = setmetatable({},WeakTable),
    ClassesMembers = setmetatable({},WeakTable),
    ClassesMetas = setmetatable({},WeakTable),
    -- In order to keep __new/__delete/__singleton from being freely available and used externally,
    -- they are stored in ClassesNew/ClassesDelete/ClassesSingleton instead of directly in the class.
    ClassesNew = setmetatable({},WeakTable),
    ClassesDelete = setmetatable({},WeakTable),
    ClassesSingleton = setmetatable({},WeakTable),
    -- ObjectsAll,not 'All' Objects.
    ObjectsAll = setmetatable({},WeakTable),
    ObjectsCls = setmetatable({},WeakTable),
    ClassesStatic = setmetatable({},WeakTable),
    ClassesPermissions = Debug and setmetatable({},WeakTable) or nil,
    FinalClasses = Debug and setmetatable({},WeakTable) or nil,
    ClassesAll = Debug and setmetatable({},WeakTable) or nil,
    FinalClassesMembers = Debug and setmetatable({},WeakTable) or nil,
    -- This table only holds all unimplemented pure virtual functions.
    VirtualClassesMembers = Debug and setmetatable({},WeakTable) or nil,
    -- This table holds all the pure virtual functions.
    VirtualClassesPermissons = Debug and setmetatable({},WeakTable) or nil,
    ClassesFriends = Debug and setmetatable({},WeakTable) or nil,
    ClassesBanNew = Debug and setmetatable({},WeakTable) or nil,
    ClassesBanDelete = Debug and setmetatable({},WeakTable) or nil,
    ClassesAllFunctions = Debug and setmetatable({},WeakTable) or nil,
    ClassesAllMetaFunctions = Debug and setmetatable({}, WeakTable) or nil,
    ClassesFunctionDefined = Debug and setmetatable({}, WeakTable) or nil,
    AccessStack = Debug and {} or nil,
    ConstStack = Debug and {} or nil,
    ReservedWord = {
        [public] = true,
        [protected] = true,
        [private] = true,
        [const] = true,
        [static] = true,
        [final] = true,
        [virtual] = true,
        [override] = true,
        [mutable] = true,
        [Config.new] = true,
        [Config.delete] = true,
        [Config.is] = true,
        [Config.handlers] = true,
        [Config.set] = true,
        [Config.get] = true
    },
    RouterReservedWord = {
        [Config.new] = true,
        [Config.delete] = true,
        [Config.is] = true,
        [Config.handlers] = true,
        [Config.friends] = true,
        [Config.__new] = true,
        [Config.__delete] = true,
        [Config.__singleton] = true
    },
    Permission = Permission,
    BitsMap = BitsMap,
    __InternalConstMethod = __InternalConstMethod,
    WeakTable = WeakTable
};