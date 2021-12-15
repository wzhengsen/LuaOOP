-- Single class.
local Debug = require("OOP.Config").Debug;

local Point = class();
Point.x = 0;
Point.y = 0;
Point.data = {
    something = "",
    others = {}
};

function Point:ctor(x,y)
    assert(self.x == Point.x);
    assert(self.y == Point.y);
    assert(type(self.data) == "table");
    assert(self.data.something == "");
    if x and y then
        self.x = x;
        self.y = y;
        self.data.something = tostring(x) .. "," .. tostring(y);
    end
end

function Point:dtor()
    print(self,"The Points has been destructed here.");
end

function Point:GetXY()
    return self.x,self.y;
end

local p1 = Point.new(1,2);
assert(p1.data.something == "1,2");
assert(p1.data ~= Point.data);
assert(p1.data.others ~= Point.data.others);

Point.type = "Point";
Point.x = 5;

local p2 = Point.new();
assert(p2.type == "Point");
p2.type = nil;
assert(p2.type == nil);
local x,y = p1:GetXY();
assert(x == 1 and y == 2);
x,y = p2:GetXY();
assert(x == 5 and y == 0);

assert(p1.data ~= p2.data);
assert(p1.data.others ~= p2.data.others);

p1:delete();
p2:delete();
if Debug then
    assert(p1.x == nil);
    assert(p2.y == nil);
else
    assert(p1.x == 1);
    assert(p2.y == 0);
end

local ok,msg = pcall(p2.GetXY,p2);
assert(not ok);
print(msg);

if not class.null(p1) then
    p1:GetXY();
end

-- 10000 objects
for i = 1,10000 do
    local p = Point.new(i,i * 2);
    assert(p.x == i and p.y == i * 2);
end

return {Point = Point};