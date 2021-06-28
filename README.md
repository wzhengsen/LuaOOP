[**English**](README_EN.md)

# LuaOOP

## 0 - 概述

>LuaOOP是什么？

LuaOOP是借鉴了C++/C#的部分类设计，并使用Lua实现的面向对象模式。

>LuaOOP提供了哪些功能？

* [基本的类构造及析构](#1---基本的类构造及析构)；
* [类的单继承、多继承](#2---类的单继承多继承)；
* [访问权控制](#3---访问权控制)（public/protected/private/static/const/friends/final）；
* [全部保留字可配置](#4---全部保留字可配置)；
* [属性](#5---属性)；
* [运行时类型判断](#6---运行时类型判断)（is）;
* [元方法与运算符重载](#7---元方法与运算符重载)；
* [单例](#8---单例)（\_\_singleton\_\_）；
* [扩展或继承外部类](#9---扩展或继承外部类)（生成userdata的类）；
* [Debug和Release运行模式](#10---debug和release运行模式)；
* [简单的事件分发模式](#11---简单的事件分发模式)；
* [枚举](#12---枚举)；
* [纯虚函数](#13---纯虚函数)；
* [Lua5.1-Lua5.4兼容](#14---lua51-lua54兼容)。

>计划中或待实现

* 当const修饰方法时的新语义。

---
## 1 - 基本的类构造及析构
---
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

-- 析构函数（可以不提供，以使用默认析构）。
function Point:dtor()
    print(self,"在此处析构");
end

function Point:PrintXY()
    print("x = " .. self.x);
    print("y = " .. self.y);
end

local p1 = Point.new(1,2);
-- 表类型的成员被深拷贝，对象的成员不等于类的成员。
assert(p1.data ~= Point.data);
assert(p1.data.others ~= Point.data.others);

local p2 = Point.new();
p1:PrintXY();-- x = 1 y = 2
p2:PrintXY();-- x = 0 y = 0
-- delete方法会自动生成。
-- 此时调用析构函数。
-- 析构之后对象的内容将置空，且不能再次调用任何成员函数。
p1:delete();
p2:delete();
print(p1.x);-- nil
print(p2.x);-- nil
if not class.IsNull(p1) then
    -- 可以通过class.IsNull来判断一个对象是否已经被销毁。
    p1:PrintXY();
end
-- 引发错误。
p2:PrintXY();
```

---
## 2 - 类的单继承、多继承
---
>直接以类变量继承类：
```lua
require("OOP.Class");
local Point = class();

-- 成员x，成员y。
-- 也可以不声明或定义任何成员。
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

-- 成员z。
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

>通过类名继承类：
```lua
-- ...
-- 第一个参数为字符串，将被作为类的名字。
local Point = class("Point");
-- ...
-- 当你继承希望以类名继承一个类时，必须为当前类提供一个类型名。
local Point3D = class("Point3D","Point");
-- ...
local Color = class();
-- ...

-- 使用类名继承类时，可以继承还未定义的类。
-- 比如现在，"Vertex"还未定义，但仍然可以使用其名字继承它。
local Vertex1 = class("Vertex1","Vertex");
-- 继承Point3D与Color。
-- 混合使用类名和类变量来继承。
local Vertex = class("Vertex","Point3D",Color);
-- ...
```

---
## 3 - 访问权控制
---

---
### 3.1 - 公有修饰
---
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
>**注意：如果没有任何修饰，成员方法和成员变量默认即是public访问权，所以，以上方式和以下方式是等价的：**
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

---
### 3.2 - 保护修饰
---
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

---
### 3.3 - 私有修饰
---
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

---
### 3.4 - 静态修饰
---
当一个成员被static修饰时，表示该成员不能使用对象访问，仅可使用类访问。

特别地，构造函数和析构函数不能使用static修饰。
```lua
require("OOP.Class");
local Point = class();

Point.x = 0;
Point.y = 0;
-- 静态成员，用于统计对象总数。
Point.static.Count = 0;

function Point:ctor(x,y)
    Point.Count = Point.Count + 1;
    if x and y then
        self.x = x;
        self.y = y;
    end
end

function Point:dtor()
    Point.Count = Point.Count - 1;
end

function Point.static.ShowCount()
    print("Count = ".. Point.Count);
end

local p1 = Point.new(1,2);
Point.ShowCount();-- Count = 1
local p2 = Point.new();
Point.ShowCount();-- Count = 2
p1:delete();
Point.ShowCount();-- Count = 1
-- 引发错误，对象不能访问静态成员。
p2.ShowCount();
-- 引发错误，对象不能访问静态成员。
print(p2.Count);
```

---
### 3.5 - 常量修饰
---
```lua
require("OOP.Class");
local Test = class();
-- 现在，被const修饰的data已声明为常量，不可再修改。
Test.const.data = "123";

local test = Test.new();
print(test.data);-- "123"
-- 引发错误，常量不可修改。
test.data = "321";
-- 引发错误，常量不可修改。
Test.data = "321";
```

---
### 3.7 - final修饰
---
>不可继承的final类：
```lua
require("OOP.Class");
-- class使用final修饰后，便不可再被继承。
local FinalClass = class.final();
-- ...
local ErrorClass = class(FinalClass);--引发错误。
```

>不可重写的final成员：
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

---
### 3.7 - 友元类
---
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

---
### 3.8 - 其它事项
---
>对__init__和__del__的修饰将直接影响到new和delete方法，且无论如何，new必然是static修饰的，如：
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
>一些特殊的修饰规则：
* 构造函数和析构函数不能使用static或const修饰；
* 各个修饰符都不能同时出现一次以上；
* 不能修饰一些特殊的方法和成员（事件/单例等，见后文）。

---
## 4 - 全部保留字可配置
---

我不喜欢默认提供的保留字和函数名（如class,private,new等）或这些保留字和函数名和已有命名相冲突，应该怎么办？

在执行```require("OOP.Class");```语句之前，请修改[Config.lua](OOP/Config.lua)文件中的命名映射字段，以下列出了部分默认字段：
```lua
class = "class"
new = "new"
delete = "delete"
ctor = "ctor"
public = "public"
private = "private"
protected = "protected"
```
比如，现在将：

* **class** 重命名为 **struct**；
* **new** 重命名为 **create**；
* **delete** 重命名为 **dispose**；
* **ctor** 重命名为 **\_\_init\_\_**；
* 其它保留字命名为它们的大写。

以下代码便可正常运行：
```lua
local Config = require("OOP.Config");
Config.class = "struct";
Config.new = "create";
Config.delete = "dispose";
Config.ctor = "__init__";
Config.Qualifiers.public = "PUBLIC";
Config.Qualifiers.private = "PRIVATE";
Config.Qualifiers.protected = "PROTECTED";

require("OOP.Class");
local Test = struct();
Test.PROTECTED.data = "123";
function Test:__init__()
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

---
## 5 - 属性
---
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
function Point:SetX(x)
    self.x = x;
end

-- 其中get表示只读，set表示只写。
-- 将XY属性和Point.GetXY方法关联。
Point.get.XY = Point.GetXY;
-- 将X属性和Point.SetX方法关联，也可以使用访问权修饰符。
Point.protected.set.X = Point.SetX;
-- 也可以直接定义为成员函数。
function Point.set:Y(y)
    self.y = y;
end


local Point3D = class(Point);
Point3D.private.z = 0;
Point3D.private._Count = 0;
function Point3D:ctor(x,y,z)
    Point.ctor(self,x,y);
    if z then
        self.z = z;
    end
    Point3D.Count = Point3D.Count + 1;
end

-- 静态属性，只能使用类访问，如Point3D.Count
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

p:SetX(999);
--p.X = 999;--X现在为private权限，此处不可访问。
p.Y = 888;
-- 使用GetXY和使用XY属性是等价的。
xy = p:GetXY();
print("X = " .. xy.x);-- X = 999
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
-- 如果需要改变此行为，请修改Config.PropertyBehavior值。
p3d.XY = {x = 200,y = 300};

-- 引发错误，静态属性不能使用对象访问。
print(p3d.Count);
```

---
## 6 - 运行时类型判断
---
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

---
## 7 - 元方法与运算符重载
---
>LuaOOP的元方法的使用方式：
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

function Point:__add__(another)
    return Point.new(self.x + another.x, self.y + another.y);
end

function Point:__tostring__()
    return "x = " .. self.x .. ";y = " .. self.y .. ";";
end

local p1 = Point.new(1,2);
local p2 = Point.new(2,3);

-- 此时调用__tostring__
print(p1);-- x = 1;y = 2;
print(p2);-- x = 2;y = 3;

-- 此时调用__add__
local p3 = p1 + p2;
print(p3);-- x = 3;y = 5;
```

>为什么元方法的命名和Lua标准不同，比如__add被命名为__add__？

为了避免某些潜在的问题，LuaOOP没有使用和Lua标准相同的元方法命名，而是使用了一个替代名称。一般的，替代名称都是在原名称的基础上，追加两个下划线。

当然，你也可以更改为和Lua标准相同的名称，甚至更改为其它你愿意使用的名字。

修改**Config.Meta**字段的名称映射来改变元方法命名。

>我可以实现哪些元方法？

---
Lua版本 < 5.3时可以实现的元方法为：

|   元方法   |      替代名      |   运算符    |
| :--------: | :--------------: | :---------: |
|   __add    |   \_\_add\_\_    |    a + b    |
|   __sub    |   \_\_sub\_\_    |    a - b    |
|   __mul    |   \_\_mul\_\_    |    a * b    |
|   __div    |   \_\_div\_\_    |    a / b    |
|   __mod    |   \_\_mod\_\_    |    a % b    |
|   __pow    |   \_\_pow\_\_    |    a ^ b    |
|   __unm    |   \_\_unm\_\_    |     -b      |
|    __lt    |    \_\_lt\_\_    |    a < b    |
|    __le    |    \_\_le\_\_    |   a <= b    |
|  __concat  |  \_\_concat\_\_  |   a .. b    |
|   __call   |   \_\_call\_\_   |   a(...)    |
|    __eq    |    \_\_eq\_\_    |   a == b    |
|   __len    |   \_\_len\_\_    |     #a      |
|  __pairs   |  \_\_pairs\_\_   |  pairs(a)   |
| __tostring | \_\_tostring\_\_ | tostring(a) |
|    __gc    |    \_\_gc\_\_    |             |

---
Lua版本 = 5.3时可以额外实现的元方法为：

| 元方法 |    替代名    | 运算符 |
| :----: | :----------: | :----: |
| __idiv | \_\_idiv\_\_ | a // b |
| __band | \_\_band\_\_ | a & b  |
| __bor  | \_\_bor\_\_  | a \| b |
| __bxor | \_\_bxor\_\_ | a ~ b  |
| __shl  | \_\_shl\_\_  | a << b |
| __shr  | \_\_shr\_\_  | a >> b |
| __bnot | \_\_bnot\_\_ |   ~a   |

---
Lua版本 > 5.3时可以额外实现的元方法为：

| 元方法  |    替代名     |   运算符   |
| :-----: | :-----------: | :--------: |
| __close | \_\_close\_\_ | a\<close\> |

---
以下元方法暂时不能实现：
* __index
* __newindex
* __metatable
* __mode

---
## 8 - 单例
---
如果要使用预置的单例模式实现，请定义__singleton__方法，但如果自己有独特的实现方式，也可以采取自己的实现。
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
-- 定义__singleton__来获取单例。
function Device:__singleton__()
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

-- 引发错误，定义__singleton__后，new将被默认为protected修饰（除非已预先指明构造函数为private修饰）。
local device = Device.new();
```

---
## 9 - 扩展或继承外部类
---

在某些情况下，使用Lua C API注册了一些可以返回userdata类型的类（如io.open返回的FILE*类型），这些userdata有独立的元表和构造入口。

---
### 9.1 - 仅扩展外部类
---
```lua
require("OOP.Class");
local File = class();

-- 注册__new__方法来返回外部类生成的对象，也可以返回nil值。
-- __new__方法会改变该类的默认生成行为（默认行为是生成一个表），
-- 且该方法会被继承。
function File.__new__(...)
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

local file = File.new("D:/test","w");
file:write(file:MakeContent());

assert(getmetatable(io.stdout) == getmetatable(file));
-- 虽然io.stdout和file使用同一元表，但io.stdout并非由File类型扩展而来，
-- 所以io.stdout不能访问MakeContent方法。
print(io.stdout:MakeContent());-- 引发错误。

file:close();-- FILE*类型可以访问close方法。

-- 因为File仅扩展了返回的FILE*类型，而本身没有继承FILE*类型，
-- 所以通过File类无法访问只有FILE*能访问的域。
File.close(file);-- File无法访问close方法，引发错误。
```

---
### 9.2 - 继承外部类
---
```lua
require("OOP.Class");
-- 不同于直接扩展，现在继承FILE*类型。
local File = class(io);
-- 也可以使用如下方式：
-- local File = class(getmetatable(io.stdout).__index);

function File.__new__(...)
    return io.open(...);
end
local file = File.new("D:/test","w");
file:close();

file = File.new("D:/test","w");
File.close(file);--现在，也可以通过File来访问close方法。
```

---
### 9.3 - 外部对象的生命周期
---
>判断外部对象是否仍然可用
```lua
local Config = require("OOP.Config");

-- 可以实现Config.ExternalClass.Null函数来判断某个userdata类目前是否可用。
-- 否则class.IsNull始终对userdata类型返回true。
Config.ExternalClass.Null = function(obj)
    if getmetatable(obj) == getmetatable(io.stdout) then
        return (tostring(obj):find("(closed)")) ~= nil;
    end
end

require("OOP.Class");

local File = class(io);
function File.__new__(...)
    return io.open(...);
end

local file = File.new("D:/test","w");
print(class.IsNull(file));-- false
file:close();
print(class.IsNull(file));-- true
```

>销毁外部对象的内存

对于Lua FILE*类型，由于其内存由Lua管理，无法手动销毁并回收内存；
但对于某些自定义实现的类型，可能具有T\*\*结构，Lua内存管理除了回收T\*\*指针外，对其真正指向的内容不会回收。\
一般地，实现__delete__以销毁C/C++内存：
```lua
local ExtClass = require(...);

local Config = require("OOP.Config");
Config.ExternalClass.Null = function(obj)
    if ExtClass.CheckIsExtClass(obj) then
        return ExtClass.IsNull(obj);
    end
end

require("OOP.Class");
local LuaClass = class(ExtClass);
function LuaClass.__new__(...)
    return ExtClass.malloc(...);
end
function LuaClass:__delete__()
    ExtClass.free(self);
end
function LuaClass:dtor()
    print("LuaClass在此处析构。")
end

local obj = LuaClass.new();
print(class.IsNull(obj));-- false
-- 析构函数仍然会被调用。
obj:delete();-- "LuaClass在此处析构。"
print(class.IsNull(obj));-- true
```

---
### 9.4 - 外部类A与外部类B的继承关系
---
有时，外部类A与外部类B保持着某种继承关系，如果需要在被继承后，仍然能够使用is来判断这种继承关系，请实现Config.ExternalClass.IsInherite函数：
```lua
local Config = require("OOP.Config");
Config.ExternalClass.IsInherite = function(A,B)
    return 你的代码，要求返回boolean值；
end
```

---
## 10 - Debug和Release运行模式
---

在默认情况下，**Config.Debug**字段被赋值为**true**，这表示当前运行时需要判断访问权限和其它一些操作的合法性，因此会牺牲比较多的运行时效率。

当该字段被赋值为**false**时，绝大多数运行时检查将会跳过（比如允许对const赋值，允许外部访问private成员等），以期获得更快的运行时效率。

如果当前应用在Debug模式下已经进行了充分测试，可以更改Config.Debug为false来获取效率提升。

---
## 11 - 简单的事件分发模式
---
>直接响应事件：
```lua
require("OOP.Class");
local Listener = class();
Listener.private.name = "";
function Listener:ctor(name)
    self.name = name;
end

-- 接收名为Email的事件，携带2个额外参数。
-- 但self一定为第一个参数。
function Listener.handlers:Email(name,content)
    if name == self.name then
        -- 收到指定的邮件。
        print(content);
        -- 返回true以阻止事件再传递。
        return true;
    end
end

-- 接收事件的参数长度没有限制，比如接收有任意长度参数的名为Any的事件。
function Listener.handlers:Any(...)
    print(...);
end


local a = Listener.new("a");
local b = Listener.new("b");
local c = Listener.new("c");

-- 向b发送一封内容为123的邮件。
-- 其参数与接收函数的参数一一对应。
event.Email("b","123");

-- 发送名为Any的事件。
event.Any(1,2,3);
event.Any(nil);
event.Any("any",true,-2,function()end,{});
event.Any();
```
>指定顺序响应事件：
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

>移除事件响应：
```lua
require("OOP.Class");
local Listener = class();
function Listener.handlers:Any()
    print("响应Any事件。");
end

local a = Listener.new();
-- a-响应Any事件。
event.Any();
-- 赋值为nil以移除事件响应。
a.handlers.Any = nil;
event.Any();-- 没有任何行为。

local b = Listener.new();
-- b-响应Any事件。
event.Any();
-- b在析构后，也不再响应事件。
b:delete();
event.Any();-- 没有任何行为。
```

---
## 12 - 枚举
---
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
    Seven = enum.Auto(7),
    Eight = enum.Auto(),
    Nine = enum.Auto()
};
print(Number3.Seven);--7
print(Number3.Eight);--8
print(Number3.Nine);--9
-- 枚举不可改变。
Number3.Nine = 10;--引发错误。（或者修改Config.EnumBehavior来改变这一行为）

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

---
## 13 - 纯虚函数
---
一般地，使用**virtual**来声明一个纯虚函数。\
与c++中不同的是，virtual**只能**用来声明纯虚函数，且**不能**和其它访问限定符同时使用。
```lua
require("OOP.Class");
local Interface = class();
Interface.virtual.DoSomething1 = 0;
Interface.virtual.DoSomething2 = 0;

local Test1 = class(Interface);
function Test1:DoSomething1()
    print("DoSomething1");
end
local test1 = Test1.new();--引发错误，DoSomething2还未被重写，不能实例化。

local Test2 = class(Test1);
function Test2:DoSomething2()
    print("DoSomething2");
end
local test2 = Test2.new();
test2:DoSomething1();-- "DoSomething1"
test2:DoSomething2();-- "DoSomething2"
```

---
## 14 - Lua5.1-Lua5.4兼容
---
尽量确保Lua5.1-Lua5.4的兼容性，但LuaJIT并未测试。