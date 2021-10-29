local __file__ = ({...})[2];
local __dir__ = __file__:match("^(.+)[/\\][^/\\]+$");
local __test__ = __dir__ .. "/test";
local function RestoreFileMeta()
    -- Avoid problems arising from using debug and release at the same time,
    -- unrelated to the test code.
    local mt = getmetatable(io.stdout);
    if not _G.FileMetaIndex then
        _G.FileMetaIndex = mt.__index;
        _G.FileMetaNewIndex = mt.__newindex;
    end
    mt.__index = _G.FileMetaIndex;
    mt.__newindex = _G.FileMetaNewIndex;
end
RestoreFileMeta();

local File = class();

function File.__new__(...)
    return io.open(...);
end

function File:ctor(filename,mode)
    self.filename = filename;
    self.mode = mode;
end

function File:MakeContent()
    return "The name of file is " .. self.filename ..",and opening mode is ".. self.mode;
end

local file = File.new(__test__,"w");
local content = file:MakeContent();
file:write(content);

assert(getmetatable(io.stdout) == getmetatable(file));

local ok = pcall(function()io.stdout:MakeContent()end);
assert(not ok);

file:close();

file = File.new(__test__,"r");
assert(content == file:read("a"));
file:close();


ok = pcall(function()File.close(file);end);
assert(not ok);


File = class(io);

function File.__new__(...)
    return io.open(...);
end

file = File.new(__test__,"w");
file:close();

file = File.new(__test__,"w");
File.close(file);

os.remove(__test__);