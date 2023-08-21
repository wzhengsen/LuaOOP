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

local Config = {
    LuaVersion = tonumber(_VERSION:sub(5)) or 5.1,
    Version = "1.1.0",

    --****************Rename fields start****************
    -- If you need to rename some of the LuaOOP names to suit specific needs,
    -- please modify the following mapping.

    class = "class",
    struct = "struct",

    ["class.default"] = "default",
    ["class.delete"] = "delete",

    enum = "enum",

    event = "event",

    handlers = "handlers",

    null = "null",
    raw = "raw",
    del = "del",
    to = "to",
    object = "object",

    set = "set",
    get = "get",

    friends = "friends",

    -- If __singleton is defined,
    -- then the class can only access the singleton using the Instance property
    -- and "new" will be automatically modified to the protected.
    __singleton = "__singleton",

    -- Constructor and destructor names.
    __new = "__new",
    __delete = "__delete",

    ctor = "ctor",
    dtor = "dtor",

    -- Constructor and destructor method names.
    new = "new",
    delete = "delete",

    -- "is" method name.
    is = "is",

    -- Meta function names.
    -- You must implement the meta-function to make it work which is named Meta's value.
    Meta = {
        __add = "__add",
        __sub = "__sub",
        __mul = "__mul",
        __mod = "__mod",
        __pow = "__pow",
        __div = "__div",
        __unm = "__unm",

        __lt = "__lt",
        __le = "__le",
        __concat = "__concat",
        __call = "__call",
        __gc = "__gc",
        __eq = "__eq",
        __pairs = "__pairs",
        __len = "__len",
        __tostring = "__tostring",

        __idiv = "__idiv",
        __band = "__band",
        __bor = "__bor",
        __bxor = "__bxor",
        __shl = "__shl",
        __shr = "__shr",
        __bnot = "__bnot",

        __close = "__close"
    },

    -- Qualifiers names.
    Qualifiers = {
        public = "public",
        private = "private",
        protected = "protected",

        static = "static",
        const = "const",

        final = "final",

        virtual = "virtual",
        override = "override",
        mutable = "mutable"
    },

    -- If __singleton is defined,
    -- this property will be generated automatically.
    Instance = "Instance",

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

    -- Same as PropertyBehavior.
    EnumBehavior = 1,

    -- Same as PropertyBehavior.
    StructBehavior = 2,

    -- The default initial index of the enumeration value.
    DefaultEnumIndex = 1,

    -- "get" property will be qualified with const if this is true.
    GetPropertyAutoConst = false,

    -- Whether to clean up members in Release mode.
    ClearMembersInRelease = true,

    -- Used to extend inherited external classes.
    ExternalClass = {
        ---Function to determine if userdata is empty.
        ---@type fun(p:userdata):boolean
        Null = nil,

        ---Function to determine if a external class inherits from another external class.
        ---A class can be judged as inheriting itself.
        ---@type fun(cls:table,base:table):boolean
        IsInherite = nil
    },

    -- When the number of holes in the event response objects reaches a certain number,
    -- the list of objects is rearranged to optimise speed.
    HoleLimit = 15,

    -- The language configuration, with a nil value, means that English is used by default.
    -- Currently only English and Chinese are available, use "zh" for Chinese.
    Language = nil,

    --****************Functional fields end****************

    __internal__ = "💠",
    __cls__ = "🧬"
};

-- Reverse mapping to meta method names.
local MetaMapName = {};
Config.MetaMapName = MetaMapName;
for meta,name in pairs(Config.Meta) do
    MetaMapName[name] = meta;
end

return Config;