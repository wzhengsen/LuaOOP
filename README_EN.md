[**中文**](README.md)

# LuaOOP

## 0 - Overview

>What is LuaOOP?

LuaOOP is an object-oriented pattern that borrows some of the class design from C++/C# and implements it using Lua.

>What features LuaOOP provides?

* Basic class construction and destruction;
* Single and multiple inheritance of classes;
* Access control（public/protected/private/static/const/friends/final）;
* All reserved words are configurable;
* Properties;
* Runtime type judgment（is）;
* Meta-methods and Operator overloading;
* Singleton（\_\_singleton\_\_）;
* Extend or inherit from external classes (classes that generate userdata);
* Debug and Release run modes;
* Simple event dispatch mode;
* Enumeration;
* Pure virtual functions;
* Lua5.1-Lua5.4 compat.

> planned or to be implemented

* New semantics when const qualifies methods.

---
## 1 - Basic class construction and destruction
---
```lua
require("OOP.Class");
local Point = class();

-- member x,member y.
Point.x = 0;
Point.y = 0;
-- Members of table types can also be used, and members of table types will be deep-copied.
Point.data = {
    something = "",
    others = {}
};

-- Construction(may not be provided to use the default construction).
function Point:ctor(x,y)
    if x and y then
        self.x = x;
        self.y = y;
    end
end

-- Destruction(may not be provided to use the default Destruction).
function Point:dtor()
    print(self,"Destructed at here.");
end

function Point:PrintXY()
    print("x = " .. self.x);
    print("y = " .. self.y);
end

local p1 = Point.new(1,2);
-- The members of the table type are deep-copied and the members of the object are not equal to the members of the class.
assert(p1.data ~= Point.data);
assert(p1.data.others ~= Point.data.others);

local p2 = Point.new();
p1:PrintXY();-- x = 1 y = 2
p2:PrintXY();-- x = 0 y = 0
-- delete method will be generated automatically.
-- At this point destructor is called.
-- The content of object will be set empty after destruct
-- and no member functions can be called again.
p1:delete();
p2:delete();
print(p1.x);-- nil
print(p2.x);-- nil
if not class.IsNull(p1) then
    -- You can judge a object whether have been destructed by class.Null.
    p1:PrintXY();
end
-- Raise error.
p2:PrintXY();
```

---
## 2 - Single and multiple inheritance of class
---
>Inherite class by class variable directly:
```lua
require("OOP.Class");
local Point = class();

-- member x,member y.
-- It is also possible to not declare or define any members.
Point.x = 0;
Point.y = 0;

function Point:ctor(x,y)
    if x and y then
        self.x = x;
        self.y = y;
    end
end

function Point:dtor()
    print(self,"Point is destructed.")
end

function Point:PrintXY()
    print("x = " .. self.x);
    print("y = " .. self.y);
end

-- Point3D inherited from Point.
local Point3D = class(Point);

-- member z.
Point3D.z = 0;

function Point3D:ctor(x,y,z)
    Point.ctor(self,x,y);
    if z then
        self.z = z;
    end
end

function Point3D:dtor()
    print(self,"Point3D is destructed.")
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
    print(self,"Color is destructed.")
end

function Color:PrintRGB()
    print("r = " .. self.r);
    print("g = " .. self.g);
    print("b = " .. self.b);
end

-- Vertex inherited from Point3D and Color.
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
    -- Don't call the destructor of Color/Point/Point3D,they will be called automatically.
    print(self,"Vertex is destructed.")
end

local vertex = Vertex.new({x = 0,y = 1,z = 2},{r = 99,g = 88, b = 77});
-- Access to inherited methods, etc.
vertex:PrintXY();
vertex:PrintXYZ();
vertex:PrintRGB();

-- The destructor will be called automatically in cascade.
-- Output:
-- table: xxxxxxxx Vertex is destructed.
-- table: xxxxxxxx Point3D is destructed.
-- table: xxxxxxxx Point is destructed.
-- table: xxxxxxxx Color is destructed.
vertex:delete();
```

>Inherite class by name:
```lua
-- ...
-- It will be used as the name of class if the first parameter is a string type.
local Point = class("Point");
-- ...
-- You must provide a type name to current class,when you want to inherite from a class by name.
local Point3D = class("Point3D","Point");
-- ...
local Color = class();
-- ...

-- When you inherit a class by its name, you can inherit a class that is not yet defined.
-- For example, right now, "Vertex" is not yet defined, but you can still inherit it by its name.
local Vertex1 = class("Vertex1","Vertex");
-- Inherite from Point3D and Color.
-- Inherited by mixing class name and class variable.
local Vertex = class("Vertex","Point3D",Color);
-- ...
```

---
## 3 - Access control
---

---
### 3.1 - public
---
```lua
require("OOP.Class");
local Test = class();

-- Use public to qualify PrintMe method and data member.
Test.public.data = "123";
function Test.public:PrintMe()
    print(self.data);
end

local test = Test.new();
test:PrintMe();-- "123"
print(test.data);-- "123"
```
>**Note: If there is no qualifier,member method and member variable is public access permission in default,so,the above approach is equivalent to the follow approach:**
```lua
require("OOP.Class");
local Test = class();

-- No qualifiers are used,i.e. public access permission.
Test.data = "123";
function Test:PrintMe()
    print(self.data);
end

local test = Test.new();
test:PrintMe();-- "123"
print(test.data);-- "123"
```

---
### 3.2 - protected
---
```lua
require("OOP.Class");
local Test = class();

-- Use protected to qualify data member.
Test.protected.data = "123";
function Test:PrintMe()
    print(self.data);
end

local Test1 = class(Test);
function Test1:PrintTestData()
    -- protected members can be accessed by sub-classes.
    print(self.data);
end

local test1 = Test1.new();
test1:PrintTestData();-- "123"
local test = Test.new();
test:PrintMe();-- "123"
-- Raise error,protected member can't be accessed at here.
print(test.data);
```

---
### 3.3 - private
---
```lua
require("OOP.Class");
local Test = class();

-- Use private to qualify data member.
Test.private.data = "123";
function Test:PrintMe()
    print(self.data);
end

local Test1 = class(Test);
function Test1:PrintTestData()
    -- Raise error,private members can't be accessed by sub-classes.
    print(self.data);
end

local test = Test.new();
test:PrintMe();-- "123"
-- Raise error,private members can't be accessed at here.
print(test.data);
local test1 = Test1.new();
test1:PrintTestData();
```

---
### 3.4 - static
---
When a member is modified as static,means that the member can't be accessed by using object, but only by using class.

Spcifically,constructor and destructor can't be modified by static.
```lua
require("OOP.Class");
local Point = class();

Point.x = 0;
Point.y = 0;
-- static member,used to count the total of objects.
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
-- Raise error,objects can't access static members.
p2.ShowCount();
-- Raise error,objects can't access static members.
print(p2.Count);
```

---
### 3.5 - const
---
```lua
require("OOP.Class");
local Test = class();
-- The data modified by const is now declared as a constant and can't be changed.
Test.const.data = "123";

local test = Test.new();
print(test.data);-- "123"
-- Raise error,constants can't be changed.
test.data = "321";
-- Raise error,constants can't be changed.
Test.data = "321";
```

---
### 3.7 - final
---
>Non-inheritable final class:
```lua
require("OOP.Class");
-- After a class is modified with final, it is no longer inheritable.
local FinalClass = class.final();
-- ...
local ErrorClass = class(FinalClass);-- Raise error.
```

>Non-override final members:
```lua
require("OOP.Class");
local Base = class();
-- All of members modified by final can't be override no longer.
Base.final.member1 = "1";
Base.final.member2 = "2";
function Base.final:FinalFunc()
    -- ...
end

local ErrorClass = class(Base);
ErrorClass.member1 = 1;-- Raise error.
ErrorClass.member2 = 2;-- Raise error.
function ErrorClass:FinalFunc()-- Raise error.
end
```

---
### 3.7 - friends
---
```lua
require("OOP.Class");
local Base = class();
function Base:ShowSecret(secret)
    -- Protected and private members can be accessed through friend classes.
    print(secret.data);
    secret:ShowData();
end

local Secret = class();

-- You can use both class variables and class names to specify friendly classes.
-- The friendly class is not inheritable,even if Base is already a friend class of Secret, C2 should be explicitly indicated as another friend class.
-- Even if "C2" is not yet registered as a class, the "C2" friend class can still be pre-declared.
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
### 3.8 - Other matters
---
>The modifications to \_\_init\_\_ and \_\_del\_\_ will directly affect the new and delete methods, and in any case, new is necessarily static, e.g:
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
    -- Raise error, new is necessarily a static member,
    -- and objects cannot access static members.
    return inst.new(table.unpack(inst.args));
end
function Test.private:ctor(...)
    self.args = {...};
end
function Test.private:dtor()
end

local test1 = Test.CreateInstance(1,2,3,4);
Test.DestroyInstance(test1);

-- Raise error, new is already a private member.
local test2 = Test.new();

local test3 = Test.CreateInstance(1,2);
local copyTest = Test.CopyFromInstance(test3);

local test4 = Test.CreateInstance();
-- Raise error, delete is already a private member.
test4:delete();
```
>Some special modifying rules:
* Constructors and destructors cannot be modified with static or const;
* None of the qualifiers can appear more than once at the same time;
* Cannot qualify some special methods and members (events/singleton, etc., see later).

---
## 4 - All reserved words are configurable
---

I don't like the reserved words and function names provided by default (e.g. class, private, new, etc.) or these reserved words and function names conflict with existing naming, what should I do?

Before executing the ```require("OOP.Class");``` statement, please qualify the named mapping fields in the [Config.lua](OOP/Config.lua) file, some of the default fields are listed below:
```lua
class = "class"
new = "new"
delete = "delete"
ctor = "ctor"
public = "public"
private = "private"
protected = "protected"
```
For example, now:

* **class** renamed to **struct**;
* **new** renamed to **create**;
* **delete** renamed to **dispose**;
* **ctor** renamed to **\_\_init\_\_**;
* Other reserved words are named in their upper case.

The following code will work fine:
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

For more renameable fields, see the [Config.lua](OOP/Config.lua) file.

---
## 5 - Properties
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

-- where get means read-only, set means write-only.
-- Associate the XY property with the Point.GetXY method.
Point.get.XY = Point.GetXY;
-- Associate the X property with the Point.SetX method,you can also use the access qualifier.
Point.protected.set.X = Point.SetX;
-- It can also be defined directly as a member function.
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

-- Static properties, accessible only using classes,e.g. Point3D.Count
function Point3D.static.get.Count()
    return Point3D._Count;
end
function Point3D.static.set.Count(val)
    Point3D._Count = val;
end

function Point3D.set:X(x)
    -- Properties qualified by protected can be accessed here.
    Point.set.X(self,x);
    print("Point3D override X property.");
end

local p = Point.new(3,5);
-- Use the XY property directly, instead of calling the GetXY method.
local xy = p.XY;
print("X = " .. xy.x);-- X = 3
print("Y = " .. xy.y);-- Y = 5

p:SetX(999);
--p.X = 999;--X is now a private permission and is not accessible here.
p.Y = 888;
-- Using GetXY is equivalent to using the XY property.
xy = p:GetXY();
print("X = " .. xy.x);-- X = 999
print("Y = " .. xy.y);-- Y = 888

local p3d = Point3D.new(0,-1,0.5);
-- The X property has been overridden.
p3d.X = 100;-- "Point3D override X property."
p3d.Y = 99;
-- Properties can be inherited, and can access the properties of the base class.
xy = p3d.XY;
print("X = " .. xy.x);-- X = 100
print("Y = " .. xy.y);-- Y = 99

-- Raise error, read-only property cannot be written.
-- Accordingly, write-only attributes cannot be read.
-- If you need to change this behavior, please change the Config.PropertyBehavior value.
p3d.XY = {x = 200,y = 300};

-- Raise error, static properties cannot be accessed using objects.
print(p3d.Count);
```

---
## 6 - Runtime type judgment
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

-- 'is' method will be automatically generated, do not manually define.
-- When one argument is passed, is will determine if the object belongs to or inherits from a class.
print(a.is(A));-- true
print(a.is(B));-- false
print(b.is(A));-- true
print(c.is(A));-- false
print(d.is(A));-- true
print(d.is(B));-- true
print(d.is(C));-- true

-- Or, when no parameters are passed, "is" will return the current class.
print(c.is() == C)-- true
print(d.is() == A)-- false

-- It is also possible to use classes, rather than objects, to call "is".
print(B.is(A));-- true
print(C.is(B));-- false
print(C.is() == C)-- true
```
>**Note: When calling is either with an object or a class, you do not need to use the ":" operator, you should use the "." operator directly.**

---
## 7 - Meta-methods and Operator overloading
---
>How LuaOOP's metamethods are used:
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

-- Call __tostring__
print(p1);-- x = 1;y = 2;
print(p2);-- x = 2;y = 3;

-- Call __add__
local p3 = p1 + p2;
print(p3);-- x = 3;y = 5;
```

>Why are the metamethods named differently from the Lua standard, for example \_\_add is named \_\_add\_\_?

To avoid some potential problems, LuaOOP does not use the same metamethod naming as the Lua standard, but uses an alternative name. Typically, the alternative name is the original name with two underscores.

Of course, you can change it to the same name as the Lua standard, or even change it to something else if you wish.

Modify the name mapping of the **Config.Meta** field to change the metamethod naming.

>What meta-methods can I implement?

---
The metamethods that can be implemented with Lua version < 5.3 are:

| Metamethod |   Alternative    |  Operator   |
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
The additional metamethods that can be implemented with Lua version = 5.3 are:

| Metamethod | Alternative  | Operator |
| :--------: | :----------: | :------: |
|   __idiv   | \_\_idiv\_\_ |  a // b  |
|   __band   | \_\_band\_\_ |  a & b   |
|   __bor    | \_\_bor\_\_  |  a \| b  |
|   __bxor   | \_\_bxor\_\_ |  a ~ b   |
|   __shl    | \_\_shl\_\_  |  a << b  |
|   __shr    | \_\_shr\_\_  |  a >> b  |
|   __bnot   | \_\_bnot\_\_ |    ~a    |

---
The additional metamethods that can be implemented with Lua version > 5.3 are:

| Metamethod |  Alternative  |  Operator  |
| :--------: | :-----------: | :--------: |
|  __close   | \_\_close\_\_ | a\<close\> |

---
The following metamethods cannot be implemented at this time:
* __index
* __newindex
* __metatable
* __mode

---
## 8 - Singleton
---
To use the pre-built singleton pattern implementation, define the \_\_singleton\_\_ method, but if you have your own unique implementation, you can also take your own implementation.
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
    print("Singleton has been destructed.");
end
-- Define __singleton__ to get a singleton.
function Device:__singleton__()
    return Device.new();
end

-- After the definition of a singleton method, the Instance property is automatically generated.
-- A singleton will be automatically obtained each time the Instance property is fetched.
local inst1 = Device.Instance;
print(inst1:GetIp());-- 127.0.0.1
print(inst1:GetBattery());-- 100

-- Assigning nil to Instance clears the singleton, and you cannot assign a value other than nil to Instance.
Device.Instance = nil;-- "Singleton has been destructed."

-- Get a new singleton.
local inst2 = Device.Instance;
assert(inst1 ~= inst2);

-- Raise error, after defining __singleton__, new will be protected by default (unless the constructor is pre-specified as private).
local device = Device.new();
```

---
## 9 - Extend or inherit from external classes
---

In some cases, the Lua C API is used to register classes that can return userdata types (such as the FILE* type returned by io.open), which have separate meta-tables and construction entries.

---
### 9.1 - Extending external classes only
---
```lua
require("OOP.Class");
local File = class();

-- Register __new__ method to return the object generated by the external class, also can return nil value.
-- The __new__ method changes the default generation behavior of the class (the default behavior is to generate a table),
-- and the method will be inherited.
function File.__new__(...)
    return io.open(...);
end

-- Constructors can still be registered.
function File:ctor(filename,mode)
    -- In this case, the FILE* type in Lua is extended,
    -- You can use "." directly appending and reading values.
    self.filename = filename;
    self.mode = mode;
end

function File:MakeContent()
    return "The name of file is " .. self.filename ..",and opening mode is ".. self.mode;
end

local file = File.new("D:/test","w");
file:write(file:MakeContent());

assert(getmetatable(io.stdout) == getmetatable(file));
-- Although io.stdout and file use the same meta-table,
-- io.stdout is not extended by the File type,
-- so io.stdout cannot access the MakeContent method.
print(io.stdout:MakeContent());-- Raise error.

file:close();-- FILE* types can access the close method.

-- Because File only extends the returned FILE* type,
-- but does not inherit the FILE* type itself,
-- so it is not possible to access a field that only FILE* can access through the File class.
File.close(file);-- File cannot access the close method, raising an error.
```

---
### 9.2 - Inheritance of external classes
---
```lua
require("OOP.Class");
-- Unlike direct extensions, the FILE* type is now inherited.
local File = class(io);
-- You can also use the following:
-- local File = class(getmetatable(io.stdout).__index);

function File.__new__(...)
    return io.open(...);
end
local file = File.new("D:/test","w");
file:close();

file = File.new("D:/test","w");
File.close(file);-- Now, the close method can also be accessed through File.
```

---
### 9.3 - Life cycle of external objects
---
>Determine if an external object is still available
```lua
local Config = require("OOP.Config");

-- ExternalClass.Null function can be implemented to determine whether a userdata class is currently available.
-- Otherwise class.IsNull always returns true for the userdata type.
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

>Destroying the memory of external objects

For Lua FILE* types, since their memory is managed by Lua, it is not possible to destroy and reclaim memory manually;\
However, for some custom implemented types, which may have T\*\* structure, Lua memory management will not reclaim the contents of what they really point to, except for the T\*\* pointer.\
Generally, \_\_delete\_\_ is implemented to destroy C/C++ memory:
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
    print("LuaClass is destructed at here.")
end

local obj = LuaClass.new();
print(class.IsNull(obj));-- false
-- The destructor will still be called.
obj:delete();-- "LuaClass is destructed at here.."
print(class.IsNull(obj));-- true
```

---
### 9.4 - The inheritance relationship between external class A and external class B
---
Sometimes, external class A maintains some inheritance relationship with external class B. If you need to be able to use is to determine this inheritance relationship even after being inherited, please implement the Config.ExternalClass.IsInherite function:
```lua
local Config = require("OOP.Config");
Config.ExternalClass.IsInherite = function(A,B)
    return Your code,returns a boolean value;
end
```

---
## 10 - Debug and Release run modes
---

By default, the **Config.Debug** field is assigned the value **true**, which means that the current runtime needs to determine the legality of access permissions and other operations, thus sacrificing more runtime efficiency.

When this field is assigned the value **false**, most runtime checks will be skipped (e.g. allowing const assignments, allowing external access to private members, etc.) in order to achieve faster runtime efficiency.

If the current application has been fully tested in Debug mode, you can change Config.Debug to false to get a boost in efficiency.

---
## 11 - Simple event dispatch mode
---
>Direct response events:
```lua
require("OOP.Class");
local Listener = class();
Listener.private.name = "";
function Listener:ctor(name)
    self.name = name;
end

-- Receive an event named Email, with 2 additional parameters.
-- but 'self' must be the first argument.
function Listener.handlers:Email(name,content)
    if name == self.name then
        -- Receive the specified email.
        print(content);
        -- Returns true to prevent the event dispatching.
        return true;
    end
end

-- There is no limit to the length of the parameters of the received event, such as receiving an event named Any with arbitrary length parameters.
function Listener.handlers:Any(...)
    print(...);
end


local a = Listener.new("a");
local b = Listener.new("b");
local c = Listener.new("c");

-- Send an email to b with the content 123.
-- The parameters correspond to those of the receive function.
event.Email("b","123");

-- Send an event named Any.
event.Any(1,2,3);
event.Any(nil);
event.Any("any",true,-2,function()end,{});
event.Any();
```
>Specify the order of response events:
```lua
require("OOP.Class");
local Listener = class();
Listener.private.name = "";
function Listener:ctor(name)
    self.name = name;
end

function Listener.handlers:Any()
    print(self.name.." response 'Any' event.");
end

local a = Listener.new("a");
local b = Listener.new("b");
local c = Listener.new("c");
-- If no adjustment is made, the response order is in the order of construction.
-- Now, you can specify c as the first response to the Any event.
c.handlers.Any = 1;

-- c response 'Any' event.
-- a response 'Any' event.
-- b response 'Any' event.
event.Any();

-- Or, specify a as the last event to respond to Any.
a.handlers.Any = -1;

-- c response 'Any' event.
-- b response 'Any' event.
-- a response 'Any' event.
event.Any();
```

>Remove event response:
```lua
require("OOP.Class");
local Listener = class();
function Listener.handlers:Any()
    print("Responsing Any event.");
end

local a = Listener.new();
-- a-Responsing Any event.
event.Any();
-- Assign a value of nil to remove the event response..
a.handlers.Any = nil;
event.Any();-- There is no behavior.

local b = Listener.new();
-- b-Responsing Any event.
event.Any();
-- b also stops responding to events after destructuring.
b:delete();
event.Any();-- There is no behavior.
```

---
## 12 - Enumeration
---
In general, use **enum** to create an enumeration type.\
Unlike using a simple table directly or using a series of variables as an enumeration, the type of enumeration generated using enum is **immutable** by default.\
Similar to function types, enumeration types **will not** be assigned as members to objects as initial values.
```lua
require("OOP.Class");
-- Enumeration method 1.
local Number1 = enum("One","Two","Three");
print(Number1.One);--1
print(Number1.Two);--2
print(Number1.Three);--3

-- Enumeration method 2.
local Number2 = enum {
    Four = 4,
    Five = 5,
    Six = 6
};
print(Number2.Four);--4
print(Number2.Five);--5
print(Number2.Six);--6

-- Enumeration method 3.
local Number3 = enum {
    Seven = enum.Auto(7),
    Eight = enum.Auto(),
    Nine = enum.Auto()
};
print(Number3.Seven);--7
print(Number3.Eight);--8
print(Number3.Nine);--9
-- The enumeration is immutable.
Number3.Nine = 10;--Raise an error. (or modify Config.EnumBehavior to change this behavior)

local Test = class();
Test.Number1 = Number1;
-- Enumerations can be modified by static so that they can only be accessed by classes.
Test.static.Number2 = Number2;

local test = Test.new();
-- Enumerations are not copied to objects as members, and the object's enumeration and the class's enumeration remain the same.
assert(test.Number1 == Test.Number1);

print(Test.Number2.Four);
print(test.Number2.Four);--Raises an error, the object cannot access the static enumeration.
```

---
## 13 - Pure virtual functions
---
In general, use **virtual** to declare a pure virtual function.\
Unlike in C++, virtual can **only** be used to declare pure virtual functions, and **cannot** be used in conjunction with other access qualifiers.
```lua
require("OOP.Class");
local Interface = class();
Interface.virtual.DoSomething1 = 0;
Interface.virtual.DoSomething2 = 0;

local Test1 = class(Interface);
function Test1:DoSomething1()
    print("DoSomething1");
end
local test1 = Test1.new();--Raise an error, DoSomething2 has not been overridden and cannot be instantiated.

local Test2 = class(Test1);
function Test2:DoSomething2()
    print("DoSomething2");
end
local test2 = Test2.new();
test2:DoSomething1();-- "DoSomething1"
test2:DoSomething2();-- "DoSomething2"
```

---
## 14 - Lua5.1-Lua5.4 compat
---
Try to ensure Lua5.1-Lua5.4 compatibility, but LuaJIT is not tested.