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
local LuaVersion = Config.LuaVersion;

local public = Config.Qualifiers.public;
local private = Config.Qualifiers.private;
local protected = Config.Qualifiers.protected;
local static = Config.Qualifiers.static;
local const = Config.Qualifiers.const;
local final = Config.Qualifiers.final;
local virtual = Config.Qualifiers.virtual;
local get = Config.get;
local set = Config.set;

local BitsMap = {
    [public] = 2 ^ 0,
    [private] = 2 ^ 1,
    [protected] = 2 ^ 2,
    [static] = 2 ^ 3,
    [const] = 2 ^ 4,
    [final] = 2 ^ 5,
    [get] = 2 ^ 6,
    [set] = 2 ^ 7,
    [virtual] = 2 ^ 8,

    -- Used to instruct const methods internally,
    -- external code doesn't need to care about this.
    __InternalConstMethod = 2 ^ 9,

    max = (2 ^ 10) - 1
};
if LuaVersion > 5.2 then
    for k, v in pairs(BitsMap) do
        BitsMap[k] = math.tointeger(v);
    end
end
local Permission = {
    public = BitsMap[public],
    private = BitsMap[private],
    protected = BitsMap[protected],
    static = BitsMap[static],
    const = BitsMap[const],
    final = BitsMap[final],
    get = BitsMap[get],
    set = BitsMap[set],
    virtual = BitsMap[virtual]
};

return {
    NamedClasses = {},
    ClassesChildrenByName = {},
    AllClasses = setmetatable({},WeakTable),
    AllEnumerations = setmetatable({},WeakTable),
    ClassesReadable = setmetatable({},WeakTable),
    ClassesWritable = setmetatable({},WeakTable),
    ClassesHandlers = setmetatable({},WeakTable),
    ClassesBases = setmetatable({},WeakTable),
    -- Record which classes inherit from this class.
    ClassesChildren = setmetatable({},WeakTable),
    ClassesMembers = setmetatable({},WeakTable),
    ClassesMetas = setmetatable({},WeakTable),
    -- In order to keep __new__/__delete__/__singleton__ from being freely available and used externally,
    -- they are stored in ClassesNew/ClassesDelete/ClassesSingleton instead of directly in the class.
    ClassesNew = setmetatable({},WeakTable),
    ClassesDelete = setmetatable({},WeakTable),
    ClassesSingleton = setmetatable({},WeakTable),
    ObjectsAll = setmetatable({},WeakTable),
    ObjectsCls = setmetatable({},WeakTable),
    ClassesStaticProperties = setmetatable({},WeakTable),
    ClassesStatic = setmetatable({},WeakTable),
    ClassesPermissions = Debug and setmetatable({},WeakTable) or nil,
    FinalClasses = Debug and setmetatable({},WeakTable) or nil,
    ClassesAll = Debug and setmetatable({},WeakTable) or nil,
    FinalClassesMembers = Debug and setmetatable({},WeakTable) or nil,
    VirtualClassesMembers = Debug and setmetatable({},WeakTable) or nil,
    ClassesFriends = Debug and setmetatable({},WeakTable) or nil,
    ClassesBanNew = Debug and setmetatable({},WeakTable) or nil,
    ClassesBanDelete = Debug and setmetatable({},WeakTable) or nil,
    ClassesAllFunctions = Debug and setmetatable({},WeakTable) or nil,
    AccessStack = Debug and {} or nil,
    ConstStack = Debug and {} or nil,
    ReservedWord = {
        [Config.Qualifiers.public] = true,
        [Config.Qualifiers.protected] = true,
        [Config.Qualifiers.private] = true,
        [Config.Qualifiers.const] = true,
        [Config.Qualifiers.static] = true,
        [Config.Qualifiers.final] = true,
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
        [Config.__new__] = true,
        [Config.__delete__] = true
    },
    Permission = Permission,
    BitsMap = BitsMap,
    WeakTable = WeakTable
};