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

local Version = tonumber(_VERSION:sub(5)) or 5.1;
if Version >= 5.4 then
    warn("@on");
end
return {
    Version = Version,

    --****************Rename fields start****************
    -- If you need to rename some of the LuaOOP names to suit specific needs,
    -- please modify the following mapping.

    class = "class",

    Event = "Event",

    Handlers = "Handlers",

    Properties = "Properties",

    Friends = "Friends",

    IsNull = "IsNull",

    -- Constructor and destructor names.
    __init__ = "__init__",
    __del__ = "__del__",

    -- Constructor and destructor method names.
    new = "new",
    delete = "delete",

    -- "is" method name.
    is = "is",

    -- Meta function names.
    -- You must implement the meta-function to make it work which is named Meta's value.
    Meta = {
        __add = "__add__",
        __sub = "__sub__",
        __mul = "__mul__",
        __mod = "__mod__",
        __pow = "__pow__",
        __div = "__div__",
        __idiv = Version > 5.2 and "__idiv__" or nil,
        __band = Version > 5.2 and "__band__" or nil,
        __bor = Version > 5.2 and "__bor__" or nil,
        __bxor = Version > 5.2 and "__bxor__" or nil,
        __shl = Version > 5.2 and "__shl__" or nil,
        __shr = Version > 5.2 and "__shr__" or nil,
        __unm = "__unm__",
        __bnot = "__bnot__",
        __lt = "__lt__",
        __le = "__le__",
        __concat = "__concat__",
        __call = "__call__"
    },

    -- MetaDefault function names.
    -- You may not implement these meta-functions and use a default implementation.
    MetaDefault = {
        __gc = "__gc__",
        __eq = "__eq__",
        __pairs = "__pairs__",
        __len = "__len__",
        __close = Version > 5.3 and "__close__" or nil
    },

    -- Modifiers names.
    Modifiers = {
        Public = "Public",
        Private = "Private",
        Protected = "Protected",

        Static = "Static",
        Const = "Const"
    },

    -- If Singleton is defined,
    -- then the class can only access the singleton using the Instance property
    -- and "new" will be automatically modified to the private.
    Singleton = "Singleton",

    -- If Singleton is defined,
    -- this property will be generated automatically.
    Instance = "Instance",

    -- The prefix of event handers.
    On = "On",

    -- If a table has this key,means that the table is dead.
    DeathMarker = {},

    --****************Rename fields end****************


    --****************Functional fields start****************
    -- The following are functional configurations.

    -- Indicates whether the current mode is debug or not.
    -- When false, a more optimized speed will be used.
    Debug = true,

    -- What is the behavior when you use properties incorrectly?
    -- For example, writing a read-only property,
    -- or reading a write-only property.
    -- It works with Debug mode only.
    -- All incorrect operations will be allowed in non-debug mode.
    -------------------------------------
    -- 0 -> warning(for lua5.4 and after)
    -- 1 -> error
    -- 2 -> allow
    -- other -> ignore
    -------------------------------------
    PropertyBehavior = 1,

    -- Same as PropertyBehavior.
    ConstBehavior = 1,

    -- Allows the class to have a name.
    -- If true,You can pass the name as the first parameter to the class,
    -- and it is possible to use names to inherit a class.
    AllowClassName = true,

    -- Allows the class inherite a table.
    -- Like this: local Inherite = class({A = 1,B = 2});
    AllowInheriteTable = false,

    -- Used to extend inherited c++ classes.
    CppClass = {
        ---Function to determine if userdata is empty.
        ---@type fun(p:userdata):boolean
        Null = nil,

        ---Function to determine if class is a c++ class.
        ---If the class is a c++ class,returns constructor method name otherwise returns nil.
        ---@type fun(p:table):string?
        IsCppClass = nil,

        ---Function to determine if a c++ class inherits from another c++ class.
        ---A class can be judged as inheriting itself.
        ---@type fun(cls:table,base:table):boolean
        IsInherite = nil,
    },

    -- Whether to cache the elements to speed up the next access.
    Cache = true,

    -- When the number of holes in the event response objects reaches a certain number,
    -- the list of objects is rearranged to optimise speed.
    HoleLimit = 15,

    --****************Functional fields end****************


    --****************Other fields start****************
    -- In general, the following areas you do not need to modify.

    __r__ = "_👓_",
    __w__ = "_🖊_",
    __bases__ = "_⚾_",
    __all__ = "_🌐_",
    __pm__ = "_🔑_",
    __singleton__ = "_1️⃣_",
    __friends__ = "_👥_",
    __cls__ = "_🧬_",
    __members__ = "_📝_"

    --****************Other fields end****************
};