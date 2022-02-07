local __file__ = (arg or {...})[arg and 0 or 2];
local __dir__ = __file__:match("^(.+)[/\\][^/\\]+$");
local __test__ = __dir__ .. "/test";

local To = class("To");
To.x = 0;
To.y = 0;
function To:PrintXY()
    print("x=".. self.x);
    print("y=".. self.y);
    return self.x,self.y;
end

local convertTo = {x = 1,y = 3};
class.to(convertTo,To);
local x,y = convertTo:PrintXY();
assert(x == 1);
assert(y == 3);
assert(convertTo.is() == To);

convertTo = class.to({x = 2,y = 5},"To");
x,y = convertTo:PrintXY();
assert(x == 2);
assert(y == 5);
assert(convertTo.is() == To);

convertTo = class.to({x = 2},"To");
local ok = pcall(To.PrintXY,convertTo);
assert(ok == false);

local fileTo = io.open(__test__,"w");
class.to(fileTo,To);
fileTo.x = 2;
fileTo.y = 6;
x,y = fileTo:PrintXY();
assert(x == 2);
assert(y == 6);
assert(fileTo.is() == To);
fileTo:close();
os.remove(__test__);