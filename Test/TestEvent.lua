local Listener = class();
Listener.private.name = "";
Listener.private.want = nil;
function Listener:ctor(name,want)
    self.name = name;
    self.want = want;
end

function Listener.handlers:Email(name,content)
    if name == self.name then
        assert(content == self.want);
        return true;
    end
end

local sortB = 1;
local sortA = 3;
local sort = 0;
function Listener.handlers:Sort()
    sort = sort + 1;
    if "b" == self.name then
        assert(sort == sortB);
    elseif "a" == self.name then
        assert(sort == sortA);
    end
end

function Listener.handlers:NoEvent()
    assert(false);
end

local a = Listener.new("a","a");
local b = Listener.new("b","123");
local c = Listener.new("c",false);
event.Email("a","a");
event.Email("b","123");
event.Email("c",false);
local assertError = false;
c.handlers.Email = function(self,name,content)
    if name == self.name then
        assertError = content;
    end
end;
event.Email("c",true);
assert(assertError == true);

c.handlers.Email = false;
event.Email("c",false);
assert(assertError == true);

c.handlers.Email = true;
event.Email("c",false);
assert(assertError == false);

b.handlers.Sort = 1;
a.handlers.Sort = -1;
event.Sort();

a.handlers.NoEvent = nil;
b.handlers.NoEvent = nil;
c:delete();
event.NoEvent();