-- Multiple Inheritance.
local Point = require("Test.TestSingleClass").Point;
local Point3D = class(Point);

Point3D.z = 0;

function Point3D:ctor(x,y,z)
    Point.ctor(self,x,y);
    if z then
        self.z = z;
    end
end

function Point3D:dtor()
    print(self,"The Point3D has been destructed here.")
end

function Point3D:GetXYZ()
    local x,y = self:GetXY();
    return x,y,self.z;
end

function Point3D:GetTableXYZ()
    local x,y = self:GetXY();
    local z = self.z;
    return {
        x = x,
        y = y,
        z = z
    };
end

local Color = class("Color");
Color.r = 0;
Color.g = 0;
Color.b = 0;
function Color:ctor(r,g,b)
    if r and g and b then
        self.r = r;
        self.g = g;
        self.b = b;
    end
end

function Color:dtor()
    print(self,"The Color has been destructed here.")
end

function Color:GetRGB()
    return self.r,self.g,self.b;
end

function Color:GetTableRGB()
    return {
        r = self.r,
        g = self.g,
        b = self.b
    };
end

local Vertex = class(Point3D,Color);
function Vertex:ctor(p,c)
    if p then
        Point3D.ctor(self,p.x,p.y,p.z);
    end
    if c then
        Color.ctor(self,c.r,c.g,c.b);
    end
end

function Vertex:dtor()
    print(self,"The Vertex has been destructed here.")
end

local vertex = Vertex.new({x = 0,y = 1,z = 2},{r = 99,g = 88, b = 77});

local _x,_y = vertex:GetXY();
local x,y,z = vertex:GetXYZ();
local r,g,b = vertex:GetRGB();
assert(_x == x and _y == y);
assert(x == 0 and y == 1 and z == 2);
assert(r == 99 and g == 88 and b == 77);

local xyzT = vertex:GetTableXYZ();
local rgbT = vertex:GetTableRGB();
assert(x == xyzT.x and y == xyzT.y and z == xyzT.z);
assert(r == rgbT.r and g == rgbT.g and b == rgbT.b);

vertex:delete();


-- Using name inheritance.
local Color4 = class("Color4","Color");
Color4.a = 0;

function Color4:ctor(r,g,b,a)
    Color.ctor(self,r,g,b);
    if a then
        self.a = a;
    end
end

local c4 = Color4.new();
assert(0 == c4.a);
assert(0 == c4.r);
assert(0 == c4.g);
assert(0 == c4.b);
c4 = Color4.new(255,0,127,1);
assert(1 == c4.a);
assert(255 == c4.r);
assert(0 == c4.g);
assert(127 == c4.b);

-- Pre-inheritance.
local After = nil;
local Before = class("Before","After");
Before.dataBefore = nil;

local before = Before.new("123");
assert(before.dataBefore == nil);
assert(not (pcall(function ()
    before:GetSelfData();
end)));


function Before:ctor(data)
    if data then
        After.ctor(self,data.."_after");
        self.dataBefore = data.."_before";
    end
end

After = class("After");
function After:ctor(data)
    assert(data:sub(-6) == "_after");
    self.dataAfter = data;
end

function After:GetSelfData()
    return self.dataAfter;
end

before = Before.new("123");
assert(before.dataBefore == "123_before");
assert(before:GetSelfData() == "123_after");
