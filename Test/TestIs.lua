local A = class();
local B = class(A);
local C = class();
local D = class(B,C);

local a = A.new();
local b = B.new();
local c = C.new();
local d = D.new();


assert(a.is(A));
assert(not a.is(B));
assert(b.is(A));
assert(not c.is(A));
assert(d.is(A));
assert(d.is(B));
assert(d.is(C));

assert(c.is() == C)
assert(d.is() ~= A)

assert(B.is(A));
assert(not C.is(B));
assert(C.is() == C)