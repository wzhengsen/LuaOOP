local Debug = require("OOP.Config").Debug;
local Number1 = enum("One","Two","Three");
assert(Number1.One == 1);
assert(Number1.Two == 2);
assert(Number1.Three == 3);

local Number2 = enum {
    Four = 4,
    Five = 5,
    Six = 6
};
assert(Number2.Four == 4);
assert(Number2.Five == 5);
assert(Number2.Six == 6);

local Number3 = enum {
    Seven = enum(7),
    Eight = enum(),
    Nine = enum()
};
assert(Number3.Seven == 7);
assert(Number3.Eight == 8);
assert(Number3.Nine == 9);

local ok = pcall(function ()
    Number3.Nine = 10;
end);
assert(Debug and not ok or ok);


local Test = class();
Test.Number1 = Number1;
Test.static.Number2 = Number2;

local test = Test.new();
assert(test.Number1 == Test.Number1);

assert(Test.Number2.Four == 4);

ok = pcall(function ()
    return test.Number2.Four;
end);
assert(not ok);
