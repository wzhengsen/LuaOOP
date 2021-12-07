local Debug = require("OOP.Config").Debug;
local Interface = class();

Interface.protected.data = nil;
Interface.virtual.DoSomething1 = 0;
Interface.virtual.DoSomething2 = 0;
Interface.virtual.get.Data = 0;

local Test1 = class(Interface);
function Test1:DoSomething1()
end
local ok = pcall(function ()
    local test1 = Test1.new();
end);
if Debug then
    assert(not ok);
else
    assert(ok);
end

ok = pcall(function ()
function Test1.get.private.final:Data()
    return self.data;
end
end);
if Debug then
    assert(not ok);
else
    assert(ok);
end

local Test2 = class(Test1);
function Test2:DoSomething2()
end

ok = pcall(function ()
    local test2 = Test2.new();
    test2:DoSomething1();
    test2:DoSomething2();
end);
if Debug then
    assert(not ok);
else
    assert(ok);
end

local Test3 = class(Test2);

function Test3.set:Data(value)
    self.data = value;
end

function Test3.get:Data()
    return self.data;
end
local test3 = Test3.new();
test3.Data = "Hello";
assert(test3.Data == "Hello");