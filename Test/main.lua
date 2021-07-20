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

local Config = require("OOP.Config");
Config.Debug = true;
local Debug = Config.Debug;
require("OOP.Class");

-- Simple test.
local Simple = class();
Simple.static.const.private.HelloWorld = "你好世界！";

Simple.myName = "simple";
function Simple:ctor(myName)
    if myName then
        self.myName = myName;
    end
end

function Simple:Say()
    print(Simple.HelloWorld);
    print(self.myName);
    return self.myName;
end

local simple1 = Simple.new("Lua");
local simple2 = Simple.new();
assert(simple1:Say() == "Lua");
assert(simple2:Say() == "simple");
simple1:delete()
assert(class.null(simple1));
assert(not class.null(simple2));

-- Inherite.
local Base1 = class();
Base1.A = "A";
Base1.private.pointer = nil;
function Base1:ctor(prefix)
    self.name = prefix .. Base1.A;
end

local Base2 = class();
function Base2:ctor(num)
    self.num = num;
end

local Base3 = class(Base1);
function Base3:PrintName()
    print(self.name);
end

local C1 = class(Base2,Base3);
function C1:ctor(obj)
    Base1.ctor(self,"112233");
    Base2.ctor(self,1122);
    if obj then
        obj:PrintExt();
    end
end

function C1:Show()
    self:PrintName();
    print(self.num);
    print(C1.A);
end

local c1 = C1.new();
c1:Show();
local ret = (pcall(function ()
    print(c1.A)
end));
assert(Debug and not ret or ret);

-- Access permission.
local P1 = class();
P1.private.InternalInfo = "secret";
P1.const.Info = "123456";
function P1:ctor(ext)
    self.ext = ext;
end

function P1.static.private.PrintInternalInfo()
    print(P1.InternalInfo);
end

function P1.protected:PrintSelf()
    print(self);
    self:PrintExt();
end

function P1.private:PrintExt()
    print(self.ext);
    print(P1.PrintInternalInfo());
end

P1.friends = {"P2",C1};

local P2 = class("P2");
function P2:ctor(obj)
    self.obj = obj;
end

function P2:PrintObj()
    self.obj:PrintExt();
end

local P3 = class(P1);
function P3:ctor()
    P1.ctor(self,"exttttt");
end
function P3:ShowSelf()
    self:PrintSelf();
end
function P3:ShowExt()
    self:PrintExt();
end
local p3 = P3.new();
ret = (pcall(
    function ()
        p3:ShowExt();
    end
));
assert(Debug and not ret or ret);

ret = (pcall(
    function ()
        print(P3.InternalInfo);
    end
));
assert(Debug and not ret or ret);

ret = (pcall(
    function ()
        p3.PrintInternalInfo();
    end
));
assert(Debug and not ret or ret);

ret = (pcall(
    function ()
        P1.Info = "654321";
    end
));
assert(Debug and not ret or ret);

print(P3.Info);
p3:ShowSelf();

local p1 = P1.new("ext");
local p2 = P2.new(p1);
p2:PrintObj();

c1 = C1.new(p1);

-- properties and __singleton__.
local Point = class();
function Point:ctor(x,y)
    self._x = x;
    self._y = y;
end
function Point:Show()
    print("x = ",self._x);
    print("y = ",self.Y);
end
function Point.handlers:NewEvent(...)
    print(...);
    self:Show();
    if ({...})[1] == 1 then
        return true;
    end
end

function Point.get:X()
    return self._x;
end

function Point.get:Y()
    return self._y;
end

function Point.set:XY(val)
    self._x = val.x;
    self._y = val.y;
end

local Point3D = class(Point);
function Point3D:ctor(x,y,z)
    Point.ctor(self,x,y);
    self._z = z;
end
function Point3D:Show()
    Point.Show(self);
    print("z = ",self._z);
end

function Point3D.get:Z()
    return self._z;
end

function Point3D.set:XYZ(val)
    self.XY = val;
    self._z = val.z;
end

local pos1 = Point.new(1,2.2);
local pos2 = Point.new(-42.33,4532);
pos1:Show();
print(pos2.X,pos2.Y);

local p3d = Point3D.new(66,424,-432.3);
p3d:Show();
local p = {x = 1,y = 5,z = 0.2};
p3d.XY = p;
assert(p3d.Z == -432.3);
p3d:Show();
p3d.XYZ = p;
p3d:Show();
assert(p3d.Y == 5);
assert(p3d.Z == 0.2);

local Single = class();
function Single:ctor(name)
    self.name = name;
end
function Single:ShowMyName()
    print(self.name);
end
function Single.__singleton__()
    return Single.new("abc");
end
function Single.handlers:NewEvent(...)
    print(...);
end

Single.Instance:ShowMyName();
local a = Single.Instance;
local b = Single.Instance;
assert(a == b);
local c = Single.Instance;
Single.Instance = nil;
local d = Single.Instance;
assert(class.null(a) and a == c);
assert(not class.null(d) and d ~= c);

-- event and handlers.
event.NewEvent(3.8,"鹅嘎尔");
event.NewEvent(1,"fag",p2);