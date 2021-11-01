local Debug = require("OOP.Config").Debug;
local Point = class();

Point.private.x = 0;
Point.private.y = 0;

function Point:ctor(x,y)
    if x and y then
        self.x = x;
        self.y = y;
    end
end
function Point:GetXY()
    return {x = self.x,y = self.y};
end
function Point:SetX(x)
    self.x = x;
end

Point.get.XY = Point.GetXY;
Point.protected.set.X = Point.SetX;
function Point.set:Y(y)
    self.y = y;
end

function Point.get:Y()
    return self.y;
end


local Point3D = class(Point);
Point3D.private.z = 0;
Point3D.static.private._Count = 0;
function Point3D:ctor(x,y,z)
    Point.ctor(self,x,y);
    if z then
        self.z = z;
    end
    Point3D.Count = Point3D.Count + 1;
end

function Point3D.static.get.Count()
    return Point3D._Count;
end
function Point3D.static.set.Count(val)
    Point3D._Count = val;
end

function Point3D.set:X(x)
    Point.set.X(self,x);
end

local p = Point.new(3,5);

local xy = p.XY;
assert(xy.x == 3 and xy.y == 5);

p:SetX(999);
local ok = pcall(function ()
    return p.X;
end);
if Debug then
    assert(not ok);
else
    assert(ok);
end

p.Y = 888;
assert(p.Y == 888);

xy = p:GetXY();
assert(xy.x == 999 and xy.y == 888);

local p3d = Point3D.new(0,-1,0.5);
-- X属性已被重写。
p3d.X = 100;-- "Point3D重写X属性。"
p3d.Y = 99;
-- 属性可以被继承，可以访问基类的属性。
xy = p3d.XY;
assert(xy.x == 100 and xy.y == 99);

ok = pcall(function ()
    p3d.XY = {x = 200,y = 300};
end);
if Debug then
    assert(not ok);
else
    assert(ok);
end

assert(Point3D.Count == 1);
assert(p3d.Count == nil);