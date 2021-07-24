local Point = class();

Point.x = 0;
Point.y = 0;

function Point:ctor(x,y)
    if x and y then
        self.x = x;
        self.y = y;
    end
end

function Point:__add__(another)
    return Point.new(self.x + another.x, self.y + another.y);
end

function Point.static:__call__(...)
    return self.new(...);
end

local AnotherPoint = class(Point);
function AnotherPoint:__call__()
    return self.x,self.y;
end

local p1 = Point.new(1,2);
local p2 = Point.new(2,3);
local p3 = p1 + p2;
local p4 = Point(3,4);

assert(p1.x == 1 and p1.y == 2);
assert(p2.x == 2 and p2.y == 3);
assert(p3.x == 3 and p3.y == 5);

assert(p4.is() == Point);


local ap = AnotherPoint(1000,2000);

local x,y = ap();
assert(x == 1000);
assert(y == 2000);

local ok = pcall(function ()
    p4();
end);
assert(not ok);
