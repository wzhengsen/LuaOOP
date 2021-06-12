# LuaOOP
Lua实现的面向对象编程模式，支持属性、多继承、运算符重载、析构、访问权限制和一组简单的消息分发结构等。

## 1-开始
---
### 1.1-LuaOOP提供了哪些功能？
---
* 基本的类构造（构造及析构）；
* 类的单继承、多继承；
* 继承返回userdata的类；
* 访问权控制（Public/Protected/Private/Static/Const/Friends）；
* 全部保留字可配置项；
* 单例（Singleton）；
* 运行时类型判断（is）;
* 属性；
* 运算符重载；
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
function Point:__init__(x,y)
    if x and y then
        self.x = x;
        self.y = y;
    end
end

-- 析构函数（可以不提供）。
function Point:__del__()
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
-- 引发错误。
p1:PrintXY();
-- 引发错误。
p1:PrintXY();
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

function Point:__init__(x,y)
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

function Point3D:__init__(x,y,z)
    Point.__init__(self,x,y);
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
function Color:__init__(r,g,b)
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
function Vertex:__init__(p,c)
    if p then
        Point3D.__init__(self,p.x,p.y,p.z);
    end
    if c then
        Color.__init__(self,c.r,c.g,c.b);
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
Config.CppClass = {
    ---用于判断userdata指向的c++对象是否可用。
    ---@type fun(p:userdata):boolean
    Null = nil,

    ---用于判断某个表是否是可以产生userdata对象的类，
    ---如果是，则返回构造userdata对象的 #函数名字#，
    ---否则返回nil值。
    ---@type fun(p:table):string?
    IsCppClass = nil,

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
function LuaImageView:__init__(png,size)
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
function LuaImageView:__init__(png)
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

function Point:__init__(x,y)
    Point.Count = Point.Count + 1;
    if x and y then
        self.x = x;
        self.y = y;
    end
end

function Point:__del__()
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
特别地，构造函数和析构函数不能使用Const修饰。
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
function Secret.Friends()
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