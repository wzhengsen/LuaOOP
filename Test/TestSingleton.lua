local Debug = require("OOP.Config").Debug;
local Device = class();
Device.private.ip = "";
Device.private.battery = 0;
function Device:ctor()
    self.ip = "127.0.0.1";
    self.battery = 100;
end
function Device:GetIp()
    return self.ip;
end
function Device:GetBattery()
    return self.battery;
end

function Device:__singleton__()
    return Device.new();
end

local inst1 = Device.Instance;
assert(inst1:GetIp() == "127.0.0.1");
assert(inst1:GetBattery() == 100);

Device.Instance = nil;

local inst2 = Device.Instance;
assert(inst1 ~= inst2);

local ok = pcall(function ()
    local device = Device.new();
end);
assert(Debug and not ok or ok);
