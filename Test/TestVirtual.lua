local Debug = require("OOP.Config").Debug;
local Interface = class();
Interface.virtual.DoSomething1 = 0;
Interface.virtual.DoSomething2 = 0;

local Test1 = class(Interface);
function Test1:DoSomething1()
end
local ok = pcall(function ()
    local test1 = Test1.new();
end);
assert(Debug and not ok or ok);

local Test2 = class(Test1);
function Test2:DoSomething2()
end
local test2 = Test2.new();
test2:DoSomething1();
test2:DoSomething2();