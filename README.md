[**English**](README_EN.md)

# LuaOOP

## 概述

### LuaOOP是什么？

LuaOOP是借鉴了C/C++/C#的类/结构体/枚举设计，并使用Lua实现的面向对象模式。

### LuaOOP提供了哪些功能？

* [类](#类)
    * [构造](#构造)
    * [析构](#析构)
* [继承](#继承)
    * [单继承](#单继承)
    * [多继承](#多继承)
    * [名称继承](#名称继承)
    * [延迟继承](#延迟继承)
* [访问权](#访问权)
    * [公有](#公有)
    * [保护](#保护)
    * [私有](#私有)
    * [静态](#静态)
    * [常量](#常量)
    * [友元](#友元)
    * [final](#final)
        * [不可继承](#不可继承)
        * [不可重写](#不可重写)
    * [组合](#组合)
    * [其他事项](#其他事项)
* [属性](#属性)
* [类型判断](#类型判断)
* [元方法](#元方法)
    * [标准元方法](#标准元方法)
    * [保留元方法](#保留元方法)
    * [仿元方法](#仿元方法)
        * [__new](#__new)
        * [__delete](#__delete)
        * [__singleton](#__singleton)
* [外部类和外部对象](#外部类和外部对象)
    * [扩展外部对象](#扩展外部对象)
    * [继承外部类](#继承外部类)
    * [生命周期](#生命周期)
* [事件](#事件)
    * [监听](#监听)
    * [排序](#排序)
    * [停用](#停用)
    * [重置](#重置)
    * [移除](#移除)
* [枚举](#枚举)
* [纯虚函数](#纯虚函数)
    * [签名](#签名)
* [结构体](#结构体)
    * [与类的异同](#与类的异同)
    * [创建结构体](#创建结构体)
* [配置](#配置)
    * [保留字](#保留字)
    * [功能性](#功能性)
* [兼容性](#兼容性)

## 类

### 构造
```lua
require("OOP.Class");
local Point = class();

-- 成员x，成员y。
Point.x = 0;
Point.y = 0;
-- 也可使用表类型的成员，且表类型的成员将被深拷贝。
Point.data = {
    something = "",
    others = {}
};

-- 构造函数（可以不提供，以使用默认构造）。
function Point:ctor(x,y)
    if x and y then
        self.x = x;
        self.y = y;
    end
end

function Point:PrintXY()
    print("x = " .. self.x);
    print("y = " .. self.y);
end

-- 使用new来构造，如果存在构造函数，将自动调用。
local p1 = Point.new(1,2);
local p2 = Point.new();
-- 表类型的成员被深拷贝，对象的成员不等于类的成员。
assert(p1.data ~= Point.data);
assert(p1.data.others ~= Point.data.others);
p1:PrintXY();-- x = 1 y = 2
p2:PrintXY();-- x = 0 y = 0
```

### 析构
```lua
require("OOP.Class");
local Point = class();
Point.x = 0;
Point.y = 0;

function Point:PrintXY()
    print("x = " .. self.x);
    print("y = " .. self.y);
end

-- 析构函数（可以不提供，以使用默认析构）。
function Point:dtor()
    print(self,"在此处析构");
end

local p1 = Point.new();
p1:PrintXY();-- x = 0 y = 0
-- 使用delete以销毁对象，如果存在析构，将自动调用。
p1:delete();

print(p1.x);-- nil
print(p1.y);-- nil
if not class.null(p1) then
    -- 仅能通过class.null来判断一个对象是否已经被销毁。
    p1:PrintXY();
end
-- 引发错误。
p1:PrintXY();
```

>**注意：只有在手动调用delete方法时才会调用析构函数。当对象不是被手动销毁，而是被垃圾回收触发__gc元方法或触发__close元方法时，并不会调用析构函数。**

## 继承

### 单继承
```lua
require("OOP.Class");
local Point = class();
Point.x = 0;
Point.y = 0;

function Point:ctor(x,y)
    if x and y then
        self.x = x;
        self.y = y;
    end
end

function Point:dtor()
    print(self,"Point已析构。")
end

function Point:PrintXY()
    print("x = " .. self.x);
    print("y = " .. self.y);
end

-- Point3D继承自Point。
local Point3D = class(Point);
Point3D.z = 0;

function Point3D:ctor(x,y,z)
    Point.ctor(self,x,y);
    if z then
        self.z = z;
    end
end

function Point3D:dtor()
    -- 不要再调用Point的析构函数，它会被自动调用。
    print(self,"Point3D已析构。")
end

function Point3D:PrintXYZ()
    self:PrintXY();
    print("z = " .. self.z);
end

local p3d = Point3D.new(1,2,3);
p3d:PrintXY()-- x = 1 y = 2
p3d:PrintXYZ()-- x = 1 y = 2 z = 3

-- table: xxxxxxxx Point3D已析构。
-- table: xxxxxxxx Point已析构。
p3d:delete();
```

### 多继承
```lua
require("OOP.Class");
local Point = class();
Point.x = 0;
Point.y = 0;

function Point:ctor(x,y)
    if x and y then
        self.x = x;
        self.y = y;
    end
end

function Point:dtor()
    print(self,"Point已析构。")
end

local Point3D = class(Point);
Point3D.z = 0;

function Point3D:ctor(x,y,z)
    Point.ctor(self,x,y);
    if z then
        self.z = z;
    end
end

function Point3D:dtor()
    print(self,"Point3D已析构。")
end

function Point3D:PrintXYZ()
    self:PrintXY();
    print("z = " .. self.z);
end

local Color = class();
Color.r = 0;
Color.g = 0;
Color.b = 0;
function Color:ctor(r,g,b)
    if r and g and b then
        self.r = r;
        self.g = g;
        self.b = b;
    end
end

function Color:dtor()
    print(self,"Color已析构。")
end

function Color:PrintRGB()
    print("r = " .. self.r);
    print("g = " .. self.g);
    print("b = " .. self.b);
end

-- 顶点属性继承空间点（Point3D）与颜色（Color）。
local Vertex = class(Point3D,Color);
function Vertex:ctor(p,c)
    if p then
        Point3D.ctor(self,p.x,p.y,p.z);
    end
    if c then
        Color.ctor(self,c.r,c.g,c.b);
    end
end

function Vertex:dtor()
    -- 不要再调用Color/Point/Point3D的析构函数，它们会被自动调用。
    print(self,"Vertex已析构。")
end

local vertex = Vertex.new({x = 0,y = 1,z = 2},{r = 99,g = 88, b = 77});
-- 访问继承的方法等。
vertex:PrintXY();
vertex:PrintXYZ();
vertex:PrintRGB();

-- 析构将自动级联调用。
-- 输出：
-- table: xxxxxxxx Vertex已析构。
-- table: xxxxxxxx Point3D已析构。
-- table: xxxxxxxx Point已析构。
-- table: xxxxxxxx Color已析构。
vertex:delete();
```

### 名称继承

有时，我们希望为一个类起一个名字，以便可以通过类名而不是类变量来继承它。
```lua
require("OOP.Class");
-- 第一个参数为字符串，将被作为类的名字。
local Point = class("Point");
Point.x = 0;
Point.y = 0;
-- ...
-- 当你希望以类名继承一个类时，必须为当前类提供一个类名。
local Point3D = class("Point3D","Point");
Point.z = 0;
-- ...
```

### 延迟继承

对一个拥有名字的类来说，可以使用延迟继承。\
但延迟继承并不是一个非常有用和常用的功能，但在某些特定情况下，它会发挥独特的作用。
```lua
require("OOP.Class");

local Color = class();
-- ...

-- 此时，还没有名为"Point3D"的类，但仍然可以继承它。
local Vertex = class("Vertex","Point3D",Color);
-- ...
-- 在此阶段构造的Vertex对象只有Color和Vertex自身的特征。
-- ...

-- 此时，也没有名为"Point"的类，但也可以继承它。
local Point3D = class("Point3D","Point");
-- ...
-- 在此阶段构造的Point3D对象只有自身的特征。
-- 在此阶段构造的Vertex对象只有Color/Point3D和Vertex自身的特征，没有Point的特征。
-- ...

local Point = class("Point");
-- ...
-- 此时Vertex和Point3D都具有所有基类特征。
```

## 访问权

需要特别指出的是，所有访问权规则也对[标准元方法](#标准元方法)和[属性](#属性)适用。

### 公有
```lua
require("OOP.Class");
local Test = class();

-- 使用public修饰PrintMe方法和data成员。
Test.public.data = "123";
function Test.public:PrintMe()
    print(self.data);
end

local test = Test.new();
test:PrintMe();-- "123"
print(test.data);-- "123"
```
>**注意：如果没有任何修饰，成员函数和成员变量默认即是public访问权（这和C++的默认行为不同），所以，以上方式和以下方式是等价的：**
```lua
require("OOP.Class");
local Test = class();

-- 不使用任何修饰，即是public访问权。
Test.data = "123";
function Test:PrintMe()
    print(self.data);
end

local test = Test.new();
test:PrintMe();-- "123"
print(test.data);-- "123"
```

### 保护
```lua
require("OOP.Class");
local Test = class();

-- 使用protected修饰data成员。
Test.protected.data = "123";
function Test:PrintMe()
    print(self.data);
end

local Test1 = class(Test);
function Test1:PrintTestData()
    -- protected成员可以被子类访问。
    print(self.data);
end

local test1 = Test1.new();
test1:PrintTestData();-- "123"
local test = Test.new();
test:PrintMe();-- "123"
-- 引发错误，不能在此处访问受保护的成员。
print(test.data);
```

### 私有
```lua
require("OOP.Class");
local Test = class();

-- 使用private修饰data成员。
Test.private.data = "123";
function Test:PrintMe()
    print(self.data);
end

local Test1 = class(Test);
function Test1:PrintTestData()
    -- 引发错误，private成员不可以被子类访问。
    print(self.data);
end

local test = Test.new();
test:PrintMe();-- "123"
-- 引发错误，不能在此处访问私有成员。
print(test.data);
local test1 = Test1.new();
test1:PrintTestData();
```

### 静态

当一个成员被静态修饰时，表示该成员不能使用对象访问，仅可使用类访问。\
特别地，构造函数和析构函数不能使用静态修饰。
```lua
require("OOP.Class");
local S = class();
-- 静态成员，用于统计对象总数。
S.static.Count = 0;

function S:ctor()
    S.Count = S.Count + 1;
end

function S:dtor()
    S.Count = S.Count - 1;
end

function S.static.ShowCount()
    print("Count = ".. S.Count);
end

local s1 = S.new();
S.ShowCount();-- Count = 1
local s2 = S.new();
S.ShowCount();-- Count = 2
s1:delete();
S.ShowCount();-- Count = 1

print(s2.Count);-- nil

-- 引发错误，不能使用对象访问ShowCount，它是静态的。
s2.ShowCount();
```

### 常量

被常量修饰的成员变量不可再被修改；\
被常量修饰的成员函数中不允许调用非常量方法，也不允许修改任意成员。
```lua
require("OOP.Class");
local Other = class();
function Other:DoSomething()
end

local TestBase = class();
function TestBase:DoBase()
end

local Test = class(TestBase);
-- 现在，被const修饰的data已声明为常量，不可再修改。
Test.const.data = "123";
Test.change = "change";

local test = Test.new();
print(test.data);-- "123"
function Test.const:ConstFunc()
end
function Test:NonConstFunc()
end
-- 被常量修饰的方法。
function Test.const:ChangeValue()
    Other.new():DoSomething();-- 允许调用其它类的非const方法。
    self:ConstFunc();-- 允许调用const方法。
    self:NonConstFunc();-- 引发错误，不允许调用非const方法。
    self:DoBase();-- 引发错误，也不允许调用基类非const方法。
    self.change = "xxx";-- 引发错误，const方法内部不能修改成员。
end
test:ChangeValue();
-- 引发错误，常量不可修改。
test.data = "321";
-- 引发错误，常量不可修改。
Test.data = "321";
```

### 友元
```lua
require("OOP.Class");
local Base = class();
function Base:ShowSecret(secret)
    -- 可以通过友元类访问保护和私有成员。
    print(secret.data);
    secret:ShowData();
end

local Secret = class();

-- 可以同时使用类变量和类名来指明友元类。
-- 友元不可继承，即使Base已是Secret的友元类，C2作为另一个友元类时也应当明确指示。
-- 即便此时"C2"还未被注册为一个类，"C2"友元类仍然可以被前置声明。
Secret.friends = {Base,"C2"};

Secret.private.data = "123";
function Secret.protected:ShowData()
    print("data = " .. self.data);
end

local C2 = class("C2",Base);
function C2:ShowSecretC2(secret)
    print(secret.data);
    secret:ShowData();
end

local secret = Secret.new();
local base = Base.new();
local c2 = C2.new();
base:ShowSecret(secret);-- 123     data = 123
c2:ShowSecretC2(secret);-- 123     data = 123
```

### final

#### 不可继承
```lua
require("OOP.Class");
-- class使用final修饰后，便不可再被继承。
local FinalClass = class.final();
-- ...
local ErrorClass = class(FinalClass);--引发错误。
```

#### 不可重写
```lua
require("OOP.Class");
local Base = class();
-- final修饰后的成员都不可以再被重写。
Base.final.member1 = "1";
Base.final.member2 = "2";
function Base.final:FinalFunc()
    -- ...
end

local ErrorClass = class(Base);
ErrorClass.member1 = 1;-- 引发错误。
ErrorClass.member2 = 2;-- 引发错误。
function ErrorClass:FinalFunc()-- 引发错误。
end
```

### 组合

公有/保护/私有/静态/常量/final等可以被组合使用：
```lua
local T = class();
-- 一个名为Type的不可重写的公有静态常量。
T.public.static.const.final.Type = "T_Type";
-- 一个名为data1的私有常量。
T.private.const.data1 = {
    str = "123",
    int = 123
};

-- 错误，公有/私有/保护不能同时出现一种以上。
T.public.private.protected.data2 = 123;
-- ...
```

### 其他事项

对ctor和dtor的修饰将直接影响到new和delete方法，且无论如何，new必然是静态修饰的，如：
```lua
require("OOP.Class");
local Test = class();
function Test.static.CreateInstance(...)
    return Test.new(...);
end
function Test.static.DestroyInstance(inst)
    inst:delete();
end
function Test.static.CopyFromInstance(inst)
    -- 引发错误，new必然是静态成员，对象不能访问静态成员。
    return inst.new(table.unpack(inst.args));
end
function Test.private:ctor(...)
    self.args = {...};
end
function Test.private:dtor()
end

local test1 = Test.CreateInstance(1,2,3,4);
Test.DestroyInstance(test1);

-- 引发错误，new已是private成员。
local test2 = Test.new();

local test3 = Test.CreateInstance(1,2);
local copyTest = Test.CopyFromInstance(test3);

local test4 = Test.CreateInstance();
-- 引发错误，delete已是private成员。
test4:delete();
```

可以使用class.raw来强行突破访问权限：
```lua
require("OOP.Class");
local Test = class();
Test.private.mySecret = "123";
Test.private.myInfo = "abc";
function Test.protected:GetMyInfo()
    return self.myInfo;
end

local test = Test.new();

local forceBreak = class.raw(function()
    -- 现在已突破访问权，可以访问任意成员。
    return test:GetMyInfo(),test.mySecret;
end);
print(forceBreak());

-- 在class.raw外仍然不能访问。
print(test.mySecret);
```

class.delete和class.default：
```lua
require("OOP.Class");
-- 如果你不希望Test1被构造，可以将class.delete赋值给构造函数。
local Test1 = class();
Test1.ctor = class.delete;
local test1 = Test1.new();-- 引发错误，现在Test1类型不能被构造。

-- 继承于Test1的类也无法构造。
local Test2 = class(Test1);
local test2 = Test2.new();-- 引发错误，Test2类型也不能被构造。


-- 对于class.default，个人认为没有任何屁用，实际上是一个空函数，
-- 它的存在仅仅为了对应c++的default关键字。
```

一些特殊的修饰规则：
* 构造函数和析构函数不能使用静态或常量修饰；
* 不能修饰一些特殊的方法（[事件](#事件)/[仿元方法](#仿元方法)等）。

## 属性
```lua
require("OOP.Class");
local Point = class();

Point.private.x = 0;
Point.private.y = 0;

function Point:ctor(x,y)
    if x and y then
        self.x = x;
        self.y = y;
    end
end
function Point:GetXY()
    return {x = self.x,y = self.y};
end

-- 其中get表示只读，set表示只写。
-- 将XY属性和Point.GetXY方法关联。
Point.get.XY = Point.GetXY;
-- 也可以直接定义为成员函数。
function Point.protected.set:X(x)
    self.x = x;
end
function Point.set:Y(y)
    self.y = y;
end

local Point3D = class(Point);
Point3D.private.z = 0;
Point3D.static.private._Count = 0;
function Point3D:ctor(x,y,z)
    Point.ctor(self,x,y);
    if z then
        self.z = z;
    end
    Point3D.Count = Point3D.Count + 1;
end

-- 静态属性，只能通过类访问。
function Point3D.static.get.Count()
    return Point3D._Count;
end
function Point3D.static.set.Count(val)
    Point3D._Count = val;
end

function Point3D.set:X(x)
    -- 可以在此访问被protected修饰的属性。
    Point.set.X(self,x);
    print("Point3D重写X属性。");
end

local p = Point.new(3,5);
-- 直接使用XY属性，而不是调用GetXY方法。
local xy = p.XY;
print("X = " .. xy.x);-- X = 3
print("Y = " .. xy.y);-- Y = 5

-- 使用属性来更改y值。
p.Y = 888;
-- 使用GetXY和使用XY属性是等价的。
xy = p:GetXY();
print("X = " .. xy.x);-- X = 3
print("Y = " .. xy.y);-- Y = 888

local p3d = Point3D.new(0,-1,0.5);
-- X属性已被重写。
p3d.X = 100;-- "Point3D重写X属性。"
p3d.Y = 99;
-- 属性可以被继承，可以访问基类的属性。
xy = p3d.XY;
print("X = " .. xy.x);-- X = 100
print("Y = " .. xy.y);-- Y = 99

-- 引发错误，只读属性不能被写入。
-- 相应的，只写属性也不能被读取。
p3d.XY = {x = 200,y = 300};

-- 静态属性的访问。
print(Point3D.Count);-- 1
-- 通过对象无法访问静态属性。
print(p3d.Count);-- nil
```

## 类型判断
```lua
require("OOP.Class");
local A = class();
local B = class(A);
local C = class();
local D = class(B,C);

local a = A.new();
local b = B.new();
local c = C.new();
local d = D.new();

-- is方法会自动生成，不要手动定义。
-- 当传递一个参数时，is将判断对象是否属于或继承某类。
print(a.is(A));-- true
print(a.is(B));-- false
print(b.is(A));-- true
print(c.is(A));-- false
print(d.is(A));-- true
print(d.is(B));-- true
print(d.is(C));-- true

-- 或者，当不传递参数时，is将返回当前类。
print(c.is() == C)-- true
print(d.is() == A)-- false

-- 也可以使用类，而不是对象调用is
print(B.is(A));-- true
print(C.is(B));-- false
print(C.is() == C)-- true
```
>**注意：无论是使用对象或者类调用is时，都不必使用":"操作符，应当直接使用"."操作符。**

## 元方法

在LuaOOP中，无论是标准元方法还是仿元方法，都可以继承和重写。

### 标准元方法
```lua
require("OOP.Class");
local Point = class();
Point.protected.x = 0;
Point.protected.y = 0;

function Point:ctor(x,y)
    if x and y then
        self.x = x;
        self.y = y;
    end
end

-- 元方法也可以被修饰。
function Point.final:__add(another)
    return Point.new(self.x + another.x, self.y + another.y);
end

function Point.const:__tostring()
    return "x = " .. self.x .. ";y = " .. self.y .. ";";
end

-- 使用static修饰元方法，以使得该元方法只能通过类访问。
function Point.static:__call(...)
    return self.new(...);
end

local AnotherPoint = class(Point);
function AnotherPoint:__call()
    return self.x,self.y;
end

local p1 = Point.new(1,2);
local p2 = Point.new(2,3);
-- 此时调用__add
local p3 = p1 + p2;
-- 此时调用static.__call
local p4 = Point(3,4);

-- 此时调用__tostring
print(p1);-- x = 1;y = 2;
print(p2);-- x = 2;y = 3;
print(p3);-- x = 3;y = 5;

print(p4.is() == Point);-- true

-- static.__call继承自Point.
local ap = AnotherPoint(1000,2000);
-- __call和static.__call相互独立。
local x,y = ap();
print(x);-- 1000
print(y);-- 2000

p4();-- 引发错误，__call被static修饰后只能使用类访问。
```

### 保留元方法

以下元方法予以保留，不能自定义，也不要通过setmetatable的方式来更改它们：
* __index
* __newindex
* __metatable
* __mode

### 仿元方法

仿元方法并不是真正的元方法，只是一些类似于元方法的成员函数，但它们有独特的作用和用法。

#### __new

__new元方法的作用是重载new操作。和C++类似，重载new操作只会关心为对象分配的内存是什么（默认为分配一个表），而不关心构造函数的细节。\
目前可以分配的类型只能是表/用户数据/空值这三种类型。\
以下演示了如何分配表/空值，分配用户数据的情况请参见[外部类和外部对象](#外部类和外部对象)：
```lua
require("OOP.Class");
local T = class();
T.data = nil;
-- T仅接受以数字类型构造，其他构造参数一律返回nil。
function T.__new(p)
    return type(p) == "number" and {} or nil;
end
function T:ctor(p)
    self.data = p;
end
assert(T.new() == nil);
assert(T.new("123") == nil);
assert(T.new(3).data == 3);
```

#### __delete

__delete元方法的作用是重载delete操作。和C++类似，重载delete操作只会关心如何回收内存，而不关心析构函数的细节。\
并且被分配为表和空值的对象一般不需要重载delete操作，它们的内存将被Lua自动管理。\
对于被分配为用户数据的对象，其内存也是由Lua自动管理，但有些用户数据可能被设计为T**类型，在这种情况下，可能需要实现__delete元方法来回收其指向的内存，这种情况请参见[生命周期](#生命周期)。

#### __singleton

__singleton元方法的作用仅仅是为了更方便地实现单例，但该元方法不是必要的，如果自己有独特的实现方式，也可以采取自己的实现。
```lua
require("OOP.Class");
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
function Device:dtor()
    print("单例已析构。");
end
-- 定义__singleton来获取单例。
function Device:__singleton()
    return Device.new();
end

-- 单例方法定义后，自动生成Instance属性。
-- 每次获取Instance属性时将自动获取单例。
local inst1 = Device.Instance;
print(inst1:GetIp());-- 127.0.0.1
print(inst1:GetBattery());-- 100

-- 将nil赋值给Instance，可以清除单例，并且你不能给Instance赋值为nil之外的其它值。
Device.Instance = nil;-- "单例已析构。"

-- 获取新的单例。
local inst2 = Device.Instance;
assert(inst1 ~= inst2);

-- 引发错误，定义__singleton后，new将被默认为protected修饰（除非已预先指明构造函数为private修饰）。
local device = Device.new();
```

## 外部类和外部对象

在某些情况下，使用Lua C API注册了一些可以返回用户数据的类（如io.open返回的FILE*类型），这些用户数据有独立的元表和构造入口。\
有时，我们希望扩展/继承这种外部对象/外部类：

### 扩展外部对象
```lua
local __file__ = (arg or {...})[arg and 0 or 2];
local __dir__ = __file__:match("^(.+)[/\\][^/\\]+$");
local __test1__ = __dir__ .. "/test1";
local __test2__ = __dir__ .. "/test2";
--
require("OOP.Class");
local File = class();

-- 扩展一个外部对象，只需要使用__new元方法来返回这个对象即可。
function File.__new(...)
    return io.open(...);
end

-- 仍然可以注册构造函数。
function File:ctor(filename,mode)
    -- 此时，Lua中的FILE*类型被扩展，
    -- 可以直接使用"."运算符附加值与读取值。
    self.filename = filename;
    self.mode = mode;
end

function File:MakeContent()
    return "The name of file is " .. self.filename ..",and opening mode is ".. self.mode;
end

local file1 = File.new(__test1__,"w");
local file2 = io.open(__test2__,"w");

print(file1.is(File));-- true
print(File.is(io));-- false

assert(getmetatable(file2) == getmetatable(file1));
assert(file1.MakeContent ~= nil);
file1:write(file1:MakeContent());
-- 虽然file1和file2使用同一元表，但file2并非由File类型扩展而来，
-- 所以file2没有MakeContent方法。
assert(file2.MakeContent == nil);

file1:close();-- FILE*类型可以访问close方法。

-- 因为File仅扩展了返回的FILE*类型，而本身没有继承FILE*类型，
-- 所以通过File类无法访问只有FILE*能访问的域。
File.close(file2);-- File无法访问close方法，引发错误。
```

### 继承外部类
```lua
local __file__ = (arg or {...})[arg and 0 or 2];
local __dir__ = __file__:match("^(.+)[/\\][^/\\]+$");
local __test__ = __dir__ .. "/test";
--
require("OOP.Class");
-- 不同于直接扩展，现在直接继承io类型。
local File = class(io);

-- 仍然需要分配FILE*类型的用户数据。
function File.__new(...)
    return io.open(...);
end

local file = File.new(__test__,"w");
file:close();
print(file.is(File));-- true
print(File.is(io));-- true

file = File.new(__test__,"w");
File.close(file);--现在，也可以通过File来访问close方法。
```

有时，外部类cls继承于外部类base，如果需要在被继承后，仍然能够使用is来判断这种继承关系，请实现Config.ExternalClass.IsInherite函数：
```lua
local Config = require("OOP.Config");
Config.ExternalClass.IsInherite = function(cls,base)
    return 你的代码，要求返回布尔值
end
local LuaCls = class(cls);
local lc = LuaCls.new();
print(lc.is(base));-- true
print(LuaCls.is(base));-- true
```

### 生命周期

判断外部对象是否可用：
```lua
local __file__ = (arg or {...})[arg and 0 or 2];
local __dir__ = __file__:match("^(.+)[/\\][^/\\]+$");
local __test__ = __dir__ .. "/test";
--
local Config = require("OOP.Config");

-- 一般情况下，直接使用class.null即可，
-- 如果有特殊需求，可以自定义Config.ExternalClass.Null函数来判断某个外部对象是否可用。
Config.ExternalClass.Null = function(obj)
    if getmetatable(obj) == getmetatable(io.stdout) then
        return (tostring(obj):find("(closed)")) ~= nil;
    end
end

require("OOP.Class");

local File = class(io);
function File.__new(...)
    return io.open(...);
end
function File:dtor()
    self:close();
end

local file = File.new(__test__,"w");
print(class.null(file));-- false
file:delete();
print(class.null(file));-- true
```

对于Lua FILE*类型，由于其内存由Lua管理，无法手动销毁并回收内存；
但对于某些自定义实现的类型，可能具有T**结构，Lua内存管理除了回收T\*\*指针外，对其真正指向的内容不会回收。\
一般地，实现__delete以回收C/C++内存：
```lua
local ExtClass = require("你的外部函数库");
require("OOP.Class");
local LuaClass = class(ExtClass);
function LuaClass.__new(...)
    return ExtClass.你的内存分配函数(...);
end
function LuaClass:__delete()
    ExtClass.你的内存释放函数(self);
end
function LuaClass:dtor()
    print("LuaClass在此处析构。")
end

local obj = LuaClass.new();
print(class.null(obj));-- false
-- 析构函数仍然会被调用。
obj:delete();-- "LuaClass在此处析构。"
print(class.null(obj));-- true
```

## 事件

### 监听
```lua
require("OOP.Class");
local Listener = class();
Listener.private.name = "";
function Listener:ctor(name)
    self.name = name;
end

-- 使用handlers保留字的字段来监听名为Email的事件，携带2个额外参数。
-- 但self一定为第一个参数。
function Listener.handlers:Email(name,content)
    if name == self.name then
        -- 收到指定的邮件。
        print(content);
        -- 返回true以阻止事件再传递。
        return true;
    end
end

-- 监听事件的参数长度没有限制，比如监听有任意长度参数的名为Any的事件。
function Listener.handlers:Any(...)
    print(...);
end


local a = Listener.new("a");
local b = Listener.new("b");
local c = Listener.new("c");

-- 使用event保留字来发送事件。
-- 向b发送一封内容为123的邮件。
-- 其参数与接收函数的参数一一对应。
event.Email("b","123");

-- 发送名为Any的事件。
event.Any(1,2,3);
event.Any(nil);
event.Any("any",true,-2,function()end,{});
event.Any();
```

### 排序
```lua
require("OOP.Class");
local Listener = class();
Listener.private.name = "";
function Listener:ctor(name)
    self.name = name;
end

function Listener.handlers:Any()
    print(self.name.."响应Any事件。");
end

local a = Listener.new("a");
local b = Listener.new("b");
local c = Listener.new("c");
-- 如果不作调整，响应顺序按照构造的先后顺序。
-- 现在，可以指定c为第一个响应Any事件。
c.handlers.Any = 1;

-- c响应Any事件。
-- a响应Any事件。
-- b响应Any事件。
event.Any();

-- 或者，指定a为最后一个响应Any事件。
a.handlers.Any = -1;

-- c响应Any事件。
-- b响应Any事件。
-- a响应Any事件。
event.Any();
```

### 重置
```lua
require("OOP.Class");
local Listener = class();
function Listener.handlers:Any()
    print("响应Any事件->",self);
end

local a = Listener.new();
local b = Listener.new();

a.handlers.Any = function(self)
    print("a重置了Any事件的响应->",self);
end;

event.Any();
-- 响应Any事件->table: xxxxxxxxxx
-- a重置了Any事件的响应->table: xxxxxxxxxx
```

### 停用
```lua
require("OOP.Class");
local Listener = class();
function Listener.handlers:Any()
    print("响应Any事件。");
end

local a = Listener.new();
-- a-响应Any事件。
event.Any();

-- 赋值为false以停用事件响应。
a.handlers.Any = false;
event.Any();-- 没有任何行为。

-- 赋值为true以启用事件响应。
a.handlers.Any = true;
-- a-响应Any事件。
event.Any();
```

### 移除
```lua
require("OOP.Class");
local Listener = class();
function Listener.handlers:Any()
    print("响应Any事件。");
end

local a = Listener.new();
-- 赋值为nil以移除事件响应。
a.handlers.Any = nil;
event.Any();-- 没有任何行为。

local b = Listener.new();
-- b-响应Any事件。
event.Any();
-- b在析构后，也不再响应事件（意为自动移除）。
b:delete();
event.Any();-- 没有任何行为。
```

## 枚举

一般地，使用**enum**来创建一个枚举类型。\
与直接使用一个简单的表或使用一系列变量作为枚举不同的是，使用enum生成的枚举类型是默认**不可变**的。\
与函数类型相似，枚举类型**不会**被作为成员赋值给对象作为初值。
```lua
require("OOP.Class");
-- 枚举方式1。
local Number1 = enum("One","Two","Three");
print(Number1.One);--1
print(Number1.Two);--2
print(Number1.Three);--3

-- 枚举方式2。
local Number2 = enum {
    Four = 4,
    Five = 5,
    Six = 6
};
print(Number2.Four);--4
print(Number2.Five);--5
print(Number2.Six);--6

-- 枚举方式3。
local Number3 = enum {
    Seven = enum(7),
    Eight = enum(),
    Nine = enum()
};
print(Number3.Seven);--7
print(Number3.Eight);--8
print(Number3.Nine);--9
-- 枚举不可改变。
Number3.Nine = 10;--引发错误。

local Test = class();
Test.Number1 = Number1;
-- 枚举可以被static修饰，令其只能被类访问。
Test.static.Number2 = Number2;

local test = Test.new();
-- 枚举不会被作为成员复制给对象，对象的枚举和类的枚举保持相同。
assert(test.Number1 == Test.Number1);

print(Test.Number2.Four);
print(test.Number2.Four);--引发错误，对象不能访问静态枚举。
```

## 纯虚函数

一般地，使用**virtual**来声明一个纯虚函数。\
与c++中不同的是，virtual**只能**用来声明纯虚函数。
```lua
require("OOP.Class");
local Interface = class();
Interface.virtual.DoSomething1 = 0;
Interface.virtual.const.DoSomething2 = 0;

local Test1 = class(Interface);
function Test1:DoSomething1()
    print("DoSomething1");
end
local test1 = Test1.new();--引发错误，DoSomething2还未被重写，不能实例化。

local Test2 = class(Test1);
-- 注意，实现纯虚函数时，修饰符必须保持一致，否则将引发错误。
function Test2.const:DoSomething2()
    print("DoSomething2");
end
local test2 = Test2.new();
test2:DoSomething1();-- "DoSomething1"
test2:DoSomething2();-- "DoSomething2"
```

### 签名

声明纯虚函数时，可以使用签名来标注该纯虚函数的参数和返回的值。\
这些签名的含义见下表：
|签名|  类型  |
|:--:|:------:|
| s  | string |
| n  | number |
| i  |integer |
| d  | float  |
| v  |  nil   |
| ?  |  nil   |
| f  |function|
| t  | table  |
| b  |boolean |
| x  | thread |
| u  |userdata|
|... |  ...   |
| *  |任意类型|

使用签名来声明纯虚函数：
```lua
require("OOP.Class");
local Interface = class();
-- 第一个参数接受一个字符串或数字；
-- 第二个参数接受一个表或空值；
-- 返回一个布尔值和整数。
Interface.virtual.DoSomething("sn","t?").b.i = 0;

local Test = class(Interface);

-- 但实际上并不要求一定按照签名来实现，意味着签名仅仅只是一个提示。
function Test:DoSomething()
    return "something";
end
print(Test.new():DoSomething());-- something
```

## 结构体

### 与类的异同
|        |        类        | 结构体 |
|:------:|:----------------:|:------:|
| 保留字 |       class      | struct |
|  成员  |        是        |   是   |
|  构造  |        是        |   是   |
|  析构  |        是        |   否   |
|  继承  |        是        |   是   |
|  属性  |        是        |   否   |
|  效率  |       更慢       |  更快  |
| 元方法 |        是        |   是   |
| 修饰符 |        是        |   否   |
| 实例化 |    T.new(...)    | T(...) |
|名字继承|        是        |   否   |
|延迟继承|        是        |   否   |
|事件监听|        是        |   否   |
|纯虚函数|        是        |   否   |
|内存分配| 表/用户数据/空值 |   表   |


### 创建结构体
```lua
require("OOP.Class");
local Vec2 = struct {
    x = 0,
    y = 0
};
function Vec2:ctor(x,y)
    if x and y then
        self.x = x;
        self.y = y;
    end
end
function Vec2:__add(other)
    return Vec2(self.x + other.x,self.y + other.y);
end
function Vec2:__eq(other)
    for k,v in pairs(self) do
        if v ~= other[k] then
            return false;
        end
    end
    return true;
end
local v1 = Vec2(1,2);
local v2 = Vec2(1,2);
local v3 = v1 + v2;
print(v1 == v2);-- true
print(v3.x,v3.y);--2,4

-- 结构体也可以继承（当然也可以多继承）。
local Vec3 = struct(Vec2) {
    z = 0
};
function Vec3:ctor(x,y,z)
    if x and y and z then
        Vec2.ctor(self,x,y);
        self.z = z;
    end
end
function Vec3:__add(other)
    return Vec3(self.x + other.x,self.y + other.y,self.z + other.z);
end
function Vec3:Print()
    for k,v in pairs(self) do
        print(k.."=",v);
    end
end
v1 = Vec3(1,2,3);
v2 = Vec3(1,2,3);
print(v1 == v2);-- true
(v1+v2):Print();-- x=2 y=4 z=6
```

## 配置

### 保留字

我不喜欢默认提供的保留字（如private,new等）或这些保留字和已有命名相冲突，应该怎么办？

在执行```require("OOP.Class");```语句之前，请修改[Config.lua](OOP/Config.lua)文件中的命名映射字段，以下列出了部分默认字段：
```lua
new = "new"
delete = "delete"
ctor = "ctor"
public = "public"
private = "private"
protected = "protected"
```
比如，现在将：

* **new** 重命名为 **create**；
* **delete** 重命名为 **dispose**；
* **ctor** 重命名为 **__init**；
* 其他保留字命名为它们的大写。

以下代码便可正常运行：
```lua
local Config = require("OOP.Config");
Config.new = "create";
Config.delete = "dispose";
Config.ctor = "__init";
Config.Qualifiers.public = "PUBLIC";
Config.Qualifiers.private = "PRIVATE";
Config.Qualifiers.protected = "PROTECTED";

require("OOP.Class");
local Test = class();
Test.PROTECTED.data = "123";
function Test:__init()
    self.data = self.data:rep(2);
end
function Test.PRIVATE:Func1()
end
function Test.PUBLIC:PrintData()
    self:Func1();
    print("data = " .. self.data);
end
local test = Test.create();
test:PrintData();-- data = "123123"
test:dispose();
```
关于其它更多的可重命名字段，参见[Config.lua](OOP/Config.lua)文件。

### 功能性

[Config.lua](OOP/Config.lua)文件中还有一些关于功能性的配置，见下表：

|        字段名       |     默认值    |   功能性    |
|:-------------------:|:-------------:|:-----------:|
|        Debug        |     true      |设置为false时可以提高运行效率，<br/>但大多数安全性检测和访问权限制都将失效。|
|   PropertyBehavior  |       1       |写入/读取一个只读/只写属性时：<br/>0->将引发一个警告；<br/>1->将引发一个错误；<br/>2->允许该操作；<br/>其他值->忽略该操作。|
|    ConstBehavior    |       1       |修改常量修饰的值时：<br/>类似于PropertyBehavior字段。|
|    EnumBehavior     |       1       |修改枚举时：<br/>类似于PropertyBehavior字段。|
|   StructBehavior    |       2       |为结构体对象新增字段时：<br/>类似于PropertyBehavior字段。|
|   DefaultEnumIndex  |       1       |枚举值默认的起始值（默认保持为Lua风格，从1开始）。|
| GetPropertyAutoConst|     false     |get属性是否默认使用常量修饰（即使不使用const修饰符）。|
|ClearMembersInRelease|     true      |对于表对象，在销毁时是否自动清除所有键值对（仅Release模式下有效）。|
|    ExternalClass    |      nil      |见[继承外部类](#继承外部类)|
|      HoleLimit      |      15       |指示事件监听对象被回收的频率，<br/>数值越大，频率越低。|
|      Language       |      nil      |打印错误信息使用的语言，当前仅支持中文和英文。<br/>设为"zh"以切换为中文。|

## 兼容性

尽量确保Lua5.1-Lua5.4的兼容性，但LuaJIT并未测试。