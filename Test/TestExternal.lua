local __file__ = (arg or {...})[arg and 0 or 2];
local __dir__ = __file__:match("^(.+)[/\\][^/\\]+$");
local __test__ = __dir__ .. "/test";
local function RestoreFileMeta()
    -- Avoid problems arising from using debug and release at the same time,
    -- unrelated to the test code.
    local mt = getmetatable(io.stdout);
    if not _G.FileMetaStore then
        _G.FileMetaStore = {};
        for k,v in pairs(mt) do
            _G.FileMetaStore[k] = v;
        end
    end
    for k,_ in pairs(mt) do
        mt[k] = nil;
    end
    for k,v in pairs(_G.FileMetaStore) do
        mt[k] = v;
    end
end
RestoreFileMeta();

local File = class();

function File.__new(...)
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
assert(content == file:read("*a"));
file:close();


ok = pcall(function()File.close(file);end);
assert(not ok);


local FileIO = class(io);

function FileIO.__new(...)
    return io.open(...);
end

file = FileIO.new(__test__,"w");
file:close();

file = FileIO.new(__test__,"w");
FileIO.close(file);

os.remove(__test__);