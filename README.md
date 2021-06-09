# LuaOOP
Lua实现的面向对象编程模式，支持属性、多继承、运算符重载、析构、访问权限制和一组简单的消息分发结构等。

---
## 1-开始
---
---
### 1.1-LuaOOP提供了哪些功能？
---
* 基本的类构造（构造及析构）；
* 类的单继承、多继承；
* 继承返回userdata的类；
* 访问权控制（Public/Protected/Private/Static/Const/Friends）；
* 单例（Singleton）；
* 运行时类型判断（is）;
* 全部保留字可配置项；
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
local FirstClass = class();

-- 构造函数（可以不提供）。
function FirstClass:__init__(name)
    self.myName = name;
end

-- 析构函数（可以不提供）。
function FirstClass:__del__()
    print(self,"在此处析构");
end

function FirstClass:ShowName()
    print(self.myName);
end
local fc = FirstClass.new("abc");-- 此时调用构造函数。
fc:ShowName();
-- delete方法会自动生成。
-- 此时调用析构函数。
fc:delete();
```
---
### 1.3-我如何继承一个或多个类？
---
```lua
local C1 = class();
-- 你的实现代码等。
local C2 = class();
-- 你的实现代码等。

-- 继承C2。
local C3 = class(C2);
-- 你的实现代码等。

-- 继承C1与C3。
local C4 = class(C1,C3);
-- 你的实现代码等。
```
---
#### 1.3.1-我如何通过类名来继承类？
---
```lua
-- 第一个参数为字符串，将被作为类的名字。
local C1 = class("class1");
-- 你的实现代码等。

local C3 = class();
-- 你的实现代码等。

-- 继承C1与C3。
-- 当你继承希望以类名继承一个类时，必须为当前类提供一个类型名。
local C4 = class("class4","class1",C3);
-- 你的实现代码等。
```
---
#### 1.3.2-我如何通过函数来继承类？
---
```lua
-- 这将使用一个函数的返回值作为继承的类。
-- 在某些情况下，这会很有用。
local C1 = class(function(...)
    return SomeClass.new(...);
end);
-- 你的实现代码等。
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
#### 1.5.1-Public
---
```lua
local Test = class();
-- 使用Public修饰PrintMe方法。
function Test.Public:PrintMe()
    print(self);
end
```
>**注意：如果没有任何修饰，方法和成员默认即是Public访问权，所以，以上方式和以下方式是等价的：**
```lua
local Test = class();
-- 不使用任何修饰，即是Public访问权。
function Test:PrintMe()
    print(self);
end
```
---
#### 1.5.2-Protected
---
```lua
local Test = class();
-- 使用Protected修饰PrintMe方法。
function Test.Protected:PrintMe()
    print(self);
end

local Test1 = class(Test);
function Test1:DoWork()
    self:PrintMe();
end

local t1 = Test1.new();
-- 打印 table:0000000xxxxxx00x
t1:DoWork();

local t = Test.new();
-- 引发错误，不能在此处访问受保护的成员。
t:PrintMe();
```