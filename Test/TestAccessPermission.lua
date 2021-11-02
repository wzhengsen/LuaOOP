-- public
local Debug = require("OOP.Config").Debug;
local Test = class();

Test.public.data1 = "123";
Test.public.data2 = {
    field1 = {},
    field2 = false,
    field3 = 0x00,
    field4 = "Test"
};
function Test.public:ctor(data)
    if data then
        self.data1 = data;
    end
end

function Test.public:GetDatas()
    return self.data1,self.data2.field1,self.data2.field2,self.data2.field3,self.data2.field4
end

function Test.public:GetData1()
    return self.data1;
end

local Test1 = class(Test);
Test1.public.data1 = "567";
function Test1.public:GetDatas()
    return "nodata";
end

local test = Test.new();
local d1,f1,f2,f3,f4 = test:GetDatas();
assert(
    d1 == test.data1 and
    f1 == test.data2.field1 and
    f2 == test.data2.field2 and
    f3 == test.data2.field3 and
    f4 == test.data2.field4
);

local test1 = Test1.new("000");
assert(test1.data1 == "000");

test1 = Test1.new();
assert(test1:GetData1() == "567");
assert(test1:GetDatas() == "nodata");

-- protected

local Protected = class(Test);
Protected.protected.data1 = Test.data1;
function Protected.protected:GetData1()
    return self.data1;
end

function Protected.protected:SetField2(f)
    self.data2.field2 = f;
end

function Protected:Data1ToField2()
    self:SetField2(self:GetData1());
end

local protected = Protected.new();
protected:Data1ToField2();
assert(protected.data2.field2 == Test.data1);

local ok = pcall(function ()
    protected:GetData1();
end);
if Debug then
    assert(not ok);
else
    assert(ok);
end

ok = pcall(function ()
    protected:SetField2(100);
end);
if Debug then
    assert(not ok);
else
    assert(ok);
end

local VisitProtected = class(Protected);
function VisitProtected:TestProtected()
    assert(self:GetData1() == "VisitProtected");
    assert(self.data1 == self:GetData1());
    self:SetField2("vp");
    assert(self.data2.field2 == "vp");
end

local vp = VisitProtected.new("VisitProtected");
vp:TestProtected();

-- private
local Private = class();
Private.protected.data = "";
Private.private.pData = "private";
function Private.private:ctor(data)
    if data then
        self:SetData(data);
    end
end

function Private.create(...)
    return Private.new(...);
end

function Private.private:SetData(data)
    self.data = data;
end

local VisitPrivate = class(Private);

function VisitPrivate.TestPrivate()
    local vp = VisitPrivate.create("111");
    assert(vp.data == "111");
    local ok = pcall(function ()
        vp:SetData("222");
    end);
    if Debug then
        assert(not ok);
    else
        assert(ok);
    end
    ok = pcall(function ()
        return Private.new();
    end);
    if Debug then
        assert(not ok);
    else
        assert(ok);
    end
    ok = pcall(function ()
        return vp.pData;
    end);
    if Debug then
        assert(not ok);
    else
        assert(ok);
    end
end
VisitPrivate.TestPrivate();

-- static
local StaticTest = class();

StaticTest.static.value = {};
StaticTest.static.Count = 0;

ok = pcall(function ()
    function StaticTest.static:ctor()
    end
end);
if Debug then
    assert(not ok);
else
    assert(ok);
end

function StaticTest:ctor()
    StaticTest.Count = StaticTest.Count + 1;
end

local st = StaticTest.new();
assert(nil == st.value);
assert(nil == st.Count);
assert("table" == type(StaticTest.value));
assert(1 == StaticTest.Count);

local FromStatic = class(StaticTest);
local fs = FromStatic.new();
assert(nil == fs.value);
assert(nil == fs.Count);
assert("table" == type(FromStatic.value));
assert(2 == FromStatic.Count);

-- const
local ConstTest = class();
ConstTest.const.data = "123";
ConstTest.variable = "change me";

local ct = ConstTest.new();
ok = pcall(function ()
    ct.data = "321";
end);
if Debug then
    assert(not ok);
else
    assert(ok);
end

ok = pcall(function ()
    ConstTest.data = "321";
end);
if Debug then
    assert(not ok);
else
    assert(ok);
end

function ConstTest:Test()
end

function ConstTest.const:ThrowConstError1()
    self.variable = "changed";
end

function ConstTest.const:ThrowConstError2()
    self:Test();
end

ok = pcall(function ()
    ct:ThrowConstError1();
end);
if Debug then
    assert(not ok);
else
    assert(ok);
end

ok = pcall(function ()
    ct:ThrowConstError2();
end);
if Debug then
    assert(not ok);
else
    assert(ok);
end

local ConstTest1 = class(ConstTest);
ct = ConstTest1.new();
ok = pcall(function ()
    ct.data = "321";
end);
if Debug then
    assert(not ok);
else
    assert(ok);
end
ok = pcall(function ()
    ConstTest1.data = "321";
end);
if Debug then
    assert(not ok);
else
    assert(ok);
end

-- final
local FinalClass = class.final();
ok = pcall(function ()
    local ErrorClass = class(FinalClass);
end);
if Debug then
    assert(not ok);
else
    assert(ok);
end

local Base = class();
Base.final.member1 = "1";
Base.final.member2 = "2";
function Base.final:FinalFunc()
end

local ErrorClass = class(Base);
ok = pcall(function ()
    ErrorClass.member1 = 1;
end);
if Debug then
    assert(not ok);
else
    assert(ok);
end
ok = pcall(function ()
    ErrorClass.member2 = 1;
end);
if Debug then
    assert(not ok);
else
    assert(ok);
end
ok = pcall(function ()
    function ErrorClass:FinalFunc()
    end
end);
if Debug then
    assert(not ok);
else
    assert(ok);
end

ErrorClass.normalMember = 1;

function ErrorClass:NormalFunc()

end

local ErrorClass1 = class(ErrorClass);
ErrorClass1.normalMember = 2;
function ErrorClass1:NormalFunc()

end

ok = pcall(function ()
    ErrorClass1.member1 = 2;
end);
if Debug then
    assert(not ok);
else
    assert(ok);
end

ok = pcall(function ()
    function ErrorClass1:FinalFunc()
    end
end);
if Debug then
    assert(not ok);
else
    assert(ok);
end

-- friends
local Base = class();
function Base:GetSecret(secret)
    return secret:GetData();
end

local Secret = class();
Secret.friends = {Base,"C2"};

Secret.private.data = "123";
function Secret.protected:GetData()
    return self.data;
end

local C2 = class("C2",Base);
function C2:GetSecretC2(secret)
    return secret:GetData();
end
function C2.static.StaticGet(secret)
    return secret.data;
end

local NotFriend = class();
function NotFriend:GetSecret(secret)
    return secret.data;
end

local Secret1 = class(Secret);
function Secret1.protected:GetData()
    return "";
end
local s1 = Secret1.new();

local secret = Secret.new();
local base = Base.new();
local c2 = C2.new();
local nFriend = NotFriend.new();
assert("" == base:GetSecret(s1));
assert("123" == base:GetSecret(secret));
assert("123" == c2:GetSecretC2(secret));
assert("123" == C2.StaticGet(secret));
ok = pcall(function ()
    assert("123" == nFriend:GetSecret(secret));
end);
if Debug then
    assert(not ok);
else
    assert(ok);
end


-- other
local Test = class();
function Test.static.CreateInstance(...)
    return Test.new(...);
end
function Test.static.DestroyInstance(inst)
    inst:delete();
end
function Test.static.CopyFromInstance(inst)
    return inst.new(table.unpack(inst.args));
end
function Test.private:ctor(...)
    self.args = {...};
end
function Test.protected:dtor()
end

local test1 = Test.CreateInstance(1,2,3,4);
Test.DestroyInstance(test1);

ok = pcall(function ()
    local test2 = Test.new();
end);
if Debug then
    assert(not ok);
else
    assert(ok);
end

local test3 = Test.CreateInstance(1,2);
local copyTest = nil;
pcall(function ()
    copyTest = Test.CopyFromInstance(test3);
end);
assert(nil == copyTest);

local test4 = Test.CreateInstance();
ok = pcall(function ()
    test4:delete();
end);
if Debug then
    assert(not ok);
else
    assert(ok);
end

local Test = class();
Test.private.mySecret = "123";
Test.private.myInfo = "abc";
function Test.protected:GetMyInfo()
    return self.myInfo;
end

local test = Test.new();

local forceBreak = class.raw(function()
    return test:GetMyInfo(),test.mySecret;
end);
local i,s = forceBreak();
assert(s == "123" and i == "abc");

ok = pcall(function ()
    return test.mySecret;
end);
if Debug then
    assert(not ok);
else
    assert(ok);
end



local Test1 = class();
Test1.ctor = class.delete;
ok = pcall(function ()
    local test1 = Test1.new();
end);
assert(not ok);

local Test2 = class(Test1);
ok = pcall(function ()
    local test2 = Test2.new();
end);
assert(not ok);