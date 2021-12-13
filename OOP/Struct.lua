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
local Internal = require("OOP.Variant.Internal");
local Config = require("OOP.Config");
local BaseFunctions = require("OOP.BaseFunctions");
local ClassesBases = Internal.ClassesBases;
local Copy = BaseFunctions.Copy;
local struct = Config.struct;
local new = Config.new;
local ctor = Config.ctor;
local dtor = Config.dtor;

local function CopyProto(proto,sObj)
    if proto ~= nil then
        for k,v in pairs(proto) do
            local pt = type(v);
            if pt ~= "function" then
                sObj[k] = pt == "table" and Copy(v) or v;
            end
        end
    end
    local bases = ClassesBases[proto];
    if bases ~= nil then
        for _,v in ipairs(bases) do
            CopyProto(v,sObj);
        end
    end
end

local function StructBuild(...)
    local args = {...};
    return function (proto)
        local meta = {
            __index = function (_,k)
                local ret = proto[k];
                if ret ~= nil then
                    return ret;
                end
            end
        };
        proto[new] = function (...)
            local sObj = setmetatable({},meta);
            local _ctor = sObj[ctor];
            if _ctor then
                _ctor(sObj, ...);
            end
            return sObj;
        end;
        return setmetatable(proto, {
            __index = args
        });
    end;
end

local function Struct(...)

end


_G[struct] = Struct;
