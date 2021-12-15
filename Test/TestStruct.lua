local Vec2 = struct {
    x = 0,
    y = 0
};

Vec2.type = "Vec2";

function Vec2:ctor(x,y)
    self.x = x;
    self.y = y;
end

function Vec2:__add(other)
    return Vec2(self.x + other.x, self.y + other.y);
end

function Vec2:Print()
    for k,v in pairs(self) do
        print(k.." = "..v);
    end
end

local v1 = Vec2(1,2);
local v2 = Vec2(3,4);
local v3 = v1 + v2;
assert(v3.x == 4 and v3.y == 6);
assert(Vec2.type == "Vec2" and v3.type == nil);
v3:Print();

local Vec3 = struct(Vec2){
    z = 0
};

Vec3.type = "Vec3";

function Vec3:ctor(x,y,z)
    Vec2.ctor(self,x,y);
    self.z = z;
end

function Vec3:__add(other)
    return Vec3(self.x + other.x, self.y + other.y, self.z + other.z);
end

local v4 = Vec3(1,2,3);
local v5 = Vec3(4,5,6);
local v6 = v4 + v5;
assert(v6.x == 5 and v6.y == 7 and v6.z == 9);
assert(Vec3.type == "Vec3" and v6.type == nil);
v6:Print();