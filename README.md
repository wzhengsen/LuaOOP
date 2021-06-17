[**English**](README_EN.md)

# LuaOOP
Lua实现的面向对象编程模式，支持属性、多继承、运算符重载、析构、访问权限制和一组简单的消息分发结构等。

## 1-开始

---
### 1.1-LuaOOP提供了哪些功能？
---
* 基本的类构造（构造及析构）；
* 类的单继承、多继承；
* 继承返回userdata的类；
* 访问权控制（Public/Protected/Private/Static/Const/__friends__）；
* 全部保留字可配置项；
* 属性；
* 单例（__singleton__）；
* 运行时类型判断（is）;
* 元方法与运算符重载；
* Debug和Release运行模式；
* 一组简单的消息传递模式；
* lua5.1-lua5.4兼容。

---
### 1.2-如何开始第一步？
---
```lua
require("OOP.Class");
local Point = class();

-- 成员x，成员y。
Point.x = 0;
Point.y = 0;

-- 构造函数（可以不提供）。
function Point:ctor(x,y)
    if x and y then
        self.x = x;
        self.y = y;
    end
end

-- 析构函数（可以不提供）。
function Point:dtor()
    print(self,"在此处析构");
end

function Point:PrintXY()
    print("x = " .. self.x);
    print("y = " .. self.y);
end

local p1 = Point.new(1,2);
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
### 1.3-我如何继承一个或多个类？
---
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
local vertex = Vertex.new({x = 0,y = 1,z = 2},{r = 99,g = 88, b = 77});
-- 访问继承的方法等。
vertex:PrintXY();
vertex:PrintXYZ();
vertex:PrintRGB();
```

---
#### 1.3.1-我如何通过类名来继承类？
---
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
-- 继承Point3D与Color。
-- 混合使用类名和类变量来继承。
local C4 = class("Vertex","Point3D",Color);
-- ...
```

---
#### 1.3.2-我如何通过函数来继承类？
---
```lua
-- 这将使用一个函数的返回值作为继承的类。
-- 我暂且将其称为“对象的函数生成器”。
-- 对于每个类，这种函数生成器最多只能持有一个。

-- 在某些特殊情况下，这会很有用。
local Vertex = class(function(...)
    return Color.new(...);
end,Point3D);
```

---
### 1.4-我如何继承一个将创建userdata的类？
---
在某些情况下，使用Lua C API注册了一些可以返回userdata类型的类，这些userdata有独立的元表和构造入口。

我希望通过某种手段将纯lua类和产生userdata的类联系起来，一般需要在OOP.Config文件中指定几个特殊的函数：
```lua
Config.ExternalClass = {
    ---用于判断userdata指向的c++对象是否可用。
    ---@type fun(p:userdata):boolean
    Null = nil,

    ---用于判断某个表是否是可以产生userdata对象的类，
    ---如果是，则返回构造userdata对象的 #函数名字#，
    ---否则返回nil值。
    ---@type fun(p:table):string?
    IsExternalClass = nil,

    ---用于判断给定的类是否继承于另一个类。
    ---@type fun(cls:table,base:table):boolean
    IsInherite = nil,
};
```
其中Null和IsInherite是可选项，IsCppClass是必选项。
当IsCppClass被指定后，即可以继承由Lua C API创建的类了：
```lua
-- ...
-- 假设ImageView是一个返回userdata的类型，
-- 且构造函数名为"new"并接受2个参数（string和table）。
local LuaImageView = class(ImageView);
function LuaImageView:ctor(png,size)
    -- ...
    self.size = size;
    self.png = png;
    -- ...
end
function LuaImageView:Show()
    -- ...
end
local img = LuaImageView.new("myPic.png",{width = 100,height = 100});
img:Show();
```

---
#### 1.4.1-当我继承userdata类时，有哪些限制？
---
* 每个类能且仅能继承一个userdata类，否则将在继承时引发错误；
* 当继承userdata类后，创建的对象不再是table类型，而是一个userdata类型；
* 由于没有办法控制c/c++的内存回收，所以不再为这个类自动生成delete方法。如果有需要，使用者应当在c/c++中实现delete方法。

---
#### 1.4.2-当userdata构造函数的参数和我希望使用的参数不同，应当如何处理？
---
```lua
-- ...
local LuaImageView = class(function(png)
    -- ImageView仍然接受2个参数，但在外部调用时，只希望传递一个。
    return ImageView.new(png,{width = 200,height = 200})
end);
function LuaImageView:ctor(png)
    -- ...
    self.png = png;
    -- ...
end
function LuaImageView:Show()
    -- ...
end
local img = LuaImageView.new("myPic.png");
img:Show();
```

---
### 1.5-如何使用访问权限控制？
---

---
#### 1.5.1-公有修饰
---
```lua
require("OOP.Class");
local Test = class();
-- 使用Public修饰PrintMe方法。
Test.Public.data = "123";
function Test.Public:PrintMe()
    print(self.data);
end
local test = Test.new();
test:PrintMe();-- "123"
print(test.data);-- "123"
```
>**注意：如果没有任何修饰，成员方法和成员变量默认即是Public访问权，所以，以上方式和以下方式是等价的：**
```lua
require("OOP.Class");
local Test = class();
-- 不使用任何修饰，即是Public访问权。
Test.data = "123";
function Test:PrintMe()
    print(self.data);
end
local test = Test.new();
test:PrintMe();-- "123"
print(test.data);-- "123"
```

---
#### 1.5.2-保护修饰
---
```lua
require("OOP.Class");
local Test = class();
-- 使用Protected修饰data成员。
Test.Protected.data = "123";
function Test:PrintMe()
    print(self.data);
end

local Test1 = class(Test);
function Test1:PrintTestData()
    -- Protected成员可以被子类访问。
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
#### 1.5.3-私有修饰
---
```lua
require("OOP.Class");
local Test = class();
-- 使用Protected修饰data成员。
Test.Private.data = "123";
function Test:PrintMe()
    print(self.data);
end

local Test1 = class(Test);
function Test1:PrintTestData()
    -- 引发错误，Private成员不可以被子类访问。
    print(self.data);
end

local test = Test.new();
test:PrintMe();-- "123"
-- 引发错误，不能在此处访问私有成员。
print(test.data);
local test1 = Test1.new();
-- 引发错误，不能在此处访问私有成员。
test1:PrintTestData();
```

---
#### 1.5.4-静态修饰
---
当一个成员被Static修饰时，表示该成员不能使用对象访问，仅可使用类访问。

特别地，构造函数和析构函数不能使用Static修饰。
```lua
require("OOP.Class");
local Point = class();

Point.x = 0;
Point.y = 0;
-- 静态成员，用于统计对象总数。
Point.Static.Count = 0;

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

function Point.Static.ShowCount()
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
#### 1.5.5-常量修饰
---
```lua
require("OOP.Class");
local Test = class();
-- 现在，被Const修饰的data已声明为常量，不可再修改。
Test.Const.data = "123";

local test = Test.new();
print(test.data);-- "123"
-- 引发错误，常量不可修改。
test.data = "321";
-- 引发错误，常量不可修改。
Test.data = "321";
```

---
#### 1.5.6-友元类
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
Secret.Private.data = "123";
function Secret.Protected:ShowData()
    print("data = " .. self.data);
end
function Secret:__friends__()
    -- 可以同时使用类变量和类名来指明友元类。
    -- 友元不可继承，即使Base已是Secret的友元类，
    -- C2作为另一个友元类时也应当明确指示。
    return Base,"C2";
end

local C2 = class("C2",Base);

local secret = Secret.new();
local base = Base.new();
local c2 = C2.new();
base:ShowSecret(secret);-- 123     data = 123
c2:ShowSecret(secret);-- 123     data = 123
```

---
#### 1.5.7-是否还有一些其它的注意事项？
---
>对__init__和__del__的修饰将直接影响到new和delete方法，且无论如何，new必然是Static修饰的，如：
```lua
require("OOP.Class");
local Test = class();
function Test.Static.CreateInstance(...)
    return Test.new(...);
end
function Test.Static.DestroyInstance(inst)
    inst:delete();
end
function Test.Static.CopyFromInstance(inst)
    -- 引发错误，对象不能访问Static成员。
    return inst.new(table.unpack(inst.args));
end
function Test.Private:ctor(...)
    self.args = {...};
end
function Test.Private:dtor()
end

local test1 = Test.CreateInstance(1,2,3,4);
Test.DestroyInstance(test1);

-- 引发错误，new已是Private成员。
local test2 = Test.new();

local test3 = Test.CreateInstance(1,2);
local copyTest = Test.CopyFromInstance(test3);

local test4 = Test.CreateInstance();
-- 引发错误，delete已是Private成员。
test4:delete();
```
>一些特殊的修饰规则：
>* 构造函数和析构函数不能使用Static或Const修饰；
>* Public/Protected/Private不能同时出现一种以上；
>* 同一修饰符不能使用多次，比如```function SomeClass.Public.Public:Func()```是非法修饰；
>* 不能使用不存在的修饰符。

---
### 1.6-我不喜欢默认提供的保留字和函数名（如class,Private,new等）或这些保留字和函数名和已有命名相冲突，应该怎么办？
---
在执行```require("OOP.Class");```语句之前，请修改[Config.lua](OOP/Config.lua)文件中的命名映射字段，以下列出了部分默认字段：
```lua
class = "class"
new = "new"
delete = "delete"
ctor = "ctor"
Public = "Public"
Private = "Private"
Protected = "Protected"
Static = "Static"
Const = "Const"
__friends__ = "__friends__"
```
比如，现在将：

* **class** 重命名为 **struct**；
* **new** 重命名为 **create**；
* **delete** 重命名为 **dispose**；
* **\_\_init\_\_** 重命名为 **ctor**；
* 其它保留字命名为它们的小写。

以下代码便可正常运行：
```lua
local Config = require("OOP.Config");
Config.class = "struct";
Config.new = "create";
Config.delete = "dispose";
Config.ctor = "ctor";
Config.Modifiers.Public = "public";
Config.Modifiers.Private = "private";
Config.Modifiers.Protected = "protected";
require("OOP.Class");
local Test = struct();
Test.protected.data = "123";
function Test:ctor()
    self.data = self.data:rep(2);
end
function Test.private:Func1()
end
function Test.public:PrintData()
    self:Func1();
    print("data = " .. self.data);
end
local test = Test.create();
test:PrintData();-- data = "123123"
test:dispose();
```

关于其它更多的可重命名字段，参见[Config.lua](OOP/Config.lua)文件。

---
### 1.7-是否支持使用属性来简化某些Get和Set的操作？
---
```lua
require("OOP.Class");
local Point = class();

Point.Private.x = 0;
Point.Private.y = 0;

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

-- 使用Properties方法来获取属性。
function Point:__properties__()
    return {
        -- 其中r子表表示只读属性，w子表表示只写属性。
        r = {
            -- 将XY属性和Point.GetXY方法关联。
            XY = self.GetXY
        },
        w = {
            -- 将X属性和Point.SetX方法关联。
            X = self.SetX,
            -- 也可以指定一个函数来关联属性。
            -- 这个函数将成为成员函数，可以访问该类的成员变量。
            Y = function(obj,y)
                obj.y = y;
            end
        }
    };
end

local Point3D = class(Point);
Point3D.Private.z = 0;

function Point3D:ctor(x,y,z)
    Point.ctor(self,x,y);
    if z then
        self.z = z;
    end
end

local p = Point.new(3,5);
local xy = p.XY;
print("X = " .. xy.x);-- X = 3
print("Y = " .. xy.y);-- Y = 5
p.X = 999;
p.Y = 888;
-- 使用GetXY和使用XY属性是等价的。
xy = p:GetXY();
print("X = " .. xy.x);-- X = 999
print("Y = " .. xy.y);-- Y = 888


local p3d = Point3D.new(0,-1,0.5);
p3d.X = 100;
p3d.Y = 99;
-- 属性可以被继承，可以访问基类的属性。
xy = p3d.XY;
print("X = " .. xy.x);-- X = 100
print("Y = " .. xy.y);-- Y = 99

-- 引发错误，只读属性不能被写入。
-- 相应的，只写属性也不能被读取。
-- 如果需要改变此行为，请修改Config.PropertyBehavior值。
p3d.XY = {x = 200,y = 300};
```

---
### 1.8-预置的Singleton单例模式如何使用？必须使用Singleton来实现单例吗？
---
不一定非要使用预置的Singleton来获取单例，也可以自己实现适合自己的任意使用单例的方式。

如果要使用预置的单例模式实现，请定义Singleton方法：
```lua
require("OOP.Class");
local Device = class();
Device.Private.ip = "";
Device.Private.battery = 0;
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
-- 定义Singleton来获取单例。
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

-- 引发错误，定义Singleton后，new将被默认为Protected修饰（除非已预先指明构造函数为Private修饰）。
local device = Device.new();
```

---
### 1.9-我如何在运行时判断一个对象是否是某个类或是否继承某个类？
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
### 1.10-如何使用元方法实现运算符重载或者扩展某些lua功能？
---
>**注意：目前还不支持为userdata类型注册元方法。**
```lua
require("OOP.Class");
local Point = class();

Point.Private.x = 0;
Point.Private.y = 0;

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
print(p1);-- x = 1;y = 2;
print(p2);-- x = 2;y = 3;
local p3 = p1 + p2;
print(p3);-- x = 3;y = 5;
```

---
#### 1.10.1-为什么元方法的命名和Lua标准不同，比如__add被命名为__add__？
---
为了避免某些潜在的问题，LuaOOP没有使用和Lua标准相同的元方法命名，而是使用了一个替代名称。一般的，替代名称都是在原名称的基础上，追加两个下划线。

当然，你也可以更改为和Lua标准相同的名称，甚至更改为其它你愿意使用的名字。

修改**Config.Meta**字段的名称映射来改变元方法命名。

---
#### 1.10.2-我可以实现哪些元方法？
---
>Lua版本 < 5.3时可以实现的元方法为：

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

>Lua版本 = 5.3时可以额外实现的元方法为：

| 元方法 |    替代名    | 运算符 |
| :----: | :----------: | :----: |
| __idiv | \_\_idiv\_\_ | a // b |
| __band | \_\_band\_\_ | a & b  |
| __bor  | \_\_bor\_\_  | a \| b |
| __bxor | \_\_bxor\_\_ | a ~ b  |
| __shl  | \_\_shl\_\_  | a << b |
| __shr  | \_\_shr\_\_  | a >> b |
| __bnot | \_\_bnot\_\_ |   ~a   |

>Lua版本 > 5.3时可以额外实现的元方法为：

| 元方法  |    替代名     |   运算符   |
| :-----: | :-----------: | :--------: |
| __close | \_\_close\_\_ | a\<close\> |

以下元方法暂时不能实现：
* __index
* __newindex
* __metatable
* __mode

---
### 1.11-如何改善LuaOOP的运行时效率？
---
在默认情况下，**Config.Debug**字段被赋值为**true**，这表示当前运行时需要判断访问权限和其它一些操作的合法性，因此会牺牲比较多的运行时效率。

当该字段被赋值为**false**时，绝大多数运行时检查将会跳过（比如允许对Const赋值，允许访问Private成员等），以期获得更快的运行时效率。

如果当前应用在Debug模式下已经进行了充分测试，可以更改Config.Debug为false来获取效率提升。

---
### 1.12-如何使用事件而不是回调函数在对象间传递消息？
---
```lua
require("OOP.Class");
local Listener = class();
Listener.Private.name = "";
function Listener:ctor(name)
    self.name = name;
end

-- 使用.Handlers.On + 事件名来接收Email事件。
function Listener.Handlers:OnEmail(name,content)
    if name == self.name then
        -- 收到指定的邮件。
        print(content);
        -- 返回true以阻止事件再传递。
        return true;
    end
end

-- 接收事件的参数长度没有限制，比如接收有任意长度参数的名为Any的事件。
function Listener.Handlers:OnAny(...)
    print(...);
end


local l1 = Listener.new("a");
local l2 = Listener.new("b");
local l3 = Listener.new("c");

-- 向b发送一封内容为123的邮件。
Event.Email("b","123");

-- 发送名为Any的事件。
Event.Any(1,2,3);
Event.Any(nil);
Event.Any("any",true,-2,function()end,{});
Event.Any();

-- 如果Event/Handlers/On+事件名的命名方式不是你所需要的，请在Config文件中修改对应的命名映射。
```