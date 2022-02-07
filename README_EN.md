[**中文**](README.md)

# LuaOOP

## Overview

### What is LuaOOP?

LuaOOP is an object-oriented pattern that borrows some of the class design from C++/C# and implements it using Lua.

### What features LuaOOP provides?

* [Class](#class)
    * [Construction](#construction)
    * [Destruction](#destruction)
* [Inheritance](#inheritance)
    * [Single Inheritance](#single-inheritance)
    * [Multiple Inheritance](#multiple-inheritance)
    * [Name Inheritance](#name-inheritance)
    * [Delayed Inheritance](#delayed-inheritance)
* [Access Permissons](#access-permissons)
    * [public](#public)
    * [protected](#protected)
    * [private](#private)
    * [static](#static)
    * [const](#const)
    * [friends](#friends)
    * [final](#final)
        * [Non-inheritable](#non-inheritable)
        * [Non-overridable](#non-overridable)
    * [Combination](#combination)
    * [Other Matters](#other-matters)
* [Properties](#properties)
* [Type Judgment](#type-judgment)
* [Meta-methods](#meta-methods)
    * [Standard Meta-methods](#standard-meta-methods)
    * [Reserved Meta-methods](#reserved-meta-methods)
    * [Imitation Meta-methods](#Imitation-meta-methods)
        * [__new](#__new)
        * [__delete](#__delete)
        * [__singleton](#__singleton)
* [External Classes And External Objects](#external-classes-and-external-objects)
    * [Extend External Objects](#extend-external-objects)
    * [Inherite External Classes](#inherite-external-classes)
    * [Life Cycle](#life-cycle)
* [Conversion](#conversion)
* [Event](#event)
    * [Listening](#listening)
    * [Sort](#sort)
    * [Disable](#disable)
    * [Reset](#reset)
    * [Remove](#remove)
* [Enumeration](#enumeration);
* [Pure Virtual Functions](#pure-virtual-functions)
    * [Override](#Override)
    * [Signature](#signature)
* [Struct](#struct)
    * [Similarities And Differences With Classes](#similarities-and-differences-with-classes)
    * [Creating Structs](#creating-structs)
* [Configuration](#configuration)
    * [Reserved Words](#reserved-words)
    * [Functionality](#functionality)
* [Compatibility](#compatibility)

## Class

### Construction
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

-- Constructor(may not be provided to use the default constructor).
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

-- Use new to construct, and if a constructor exists, it will be called automatically.
local p1 = Point.new(1,2);
local p2 = Point.new();
-- The members of the table type are deep-copied and the members of the object are not equal to the members of the class.
assert(p1.data ~= Point.data);
assert(p1.data.others ~= Point.data.others);
p1:PrintXY();-- x = 1 y = 2
p2:PrintXY();-- x = 0 y = 0
```

### Destruction
```lua
require("OOP.Class");
local Point = class();
Point.x = 0;
Point.y = 0;

function Point:PrintXY()
    print("x = " .. self.x);
    print("y = " .. self.y);
end

-- Destructor(may not be provided to use the default destructor).
function Point:dtor()
    print(self,"Destructing here");
end

local p1 = Point.new();
p1:PrintXY();-- x = 0 y = 0
-- Use delete to destroy the object, which will be called automatically if destructor exist.
p1:delete();

print(p1.x);-- nil
print(p1.y);-- nil
if not class.null(p1) then
    -- Only class.null can be used to determine if an object has been destroyed.
    p1:PrintXY();
end
-- Raise an error.
p1:PrintXY();
```

>**Note: The destructor is only called when the delete method is called manually. The destructor is not called when the object is not destroyed manually, but when the __gc metamethod is triggered by garbage collection or when the __close metamethod is triggered.**

## Inheritance

### Single Inheritance
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
    print(self,"Point is destructured.")
end

function Point:PrintXY()
    print("x = " .. self.x);
    print("y = " .. self.y);
end

-- Point3D inherits from Point.
local Point3D = class(Point);
Point3D.z = 0;

function Point3D:ctor(x,y,z)
    Point.ctor(self,x,y);
    if z then
        self.z = z;
    end
end

function Point3D:dtor()
    -- Do not call Point's destructor again, it will be called automatically.
    print(self,"Point3D is destructured.")
end

function Point3D:PrintXYZ()
    self:PrintXY();
    print("z = " .. self.z);
end

local p3d = Point3D.new(1,2,3);
p3d:PrintXY()-- x = 1 y = 2
p3d:PrintXYZ()-- x = 1 y = 2 z = 3

-- table: xxxxxxxx Point3D is destructured.
-- table: xxxxxxxx Point is destructured.
p3d:delete();
```

### Multiple Inheritance
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
    print(self,"Point is destructured.")
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
    print(self,"Point3D is destructured.")
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
    print(self,"Color is destructured.")
end

function Color:PrintRGB()
    print("r = " .. self.r);
    print("g = " .. self.g);
    print("b = " .. self.b);
end

-- The vertex inherits from points (Point3D) and colors (Color).
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
    -- Don't call the Color/Point/Point3D destructors anymore, they will be called automatically.
    print(self,"Vertex is destructured.")
end

local vertex = Vertex.new({x = 0,y = 1,z = 2},{r = 99,g = 88, b = 77});
-- Call inherited methods.
vertex:PrintXY();
vertex:PrintXYZ();
vertex:PrintRGB();

-- The destructuring will be called automatically in cascade.
-- Output:
-- table: xxxxxxxx Vertex is destructured.
-- table: xxxxxxxx Point3D is destructured.
-- table: xxxxxxxx Point is destructured.
-- table: xxxxxxxx Color is destructured.
vertex:delete();
```

### Name Inheritance

Sometimes we want to give a name to a class so that we can inherit it by class name instead of class variables.
```lua
require("OOP.Class");
-- The first parameter is a string that will be used as the name of the class.
local Point = class("Point");
Point.x = 0;
Point.y = 0;
-- ...
-- When you wish to inherit a class by class name, you must provide a class name for the current class.
local Point3D = class("Point3D","Point");
Point.z = 0;
-- ...
```

### Delayed Inheritance

For a class with a name, delayed inheritance can be used. \
However, delayed inheritance is not a very useful and commonly used feature, but it can play a unique role in some specific cases.
```lua
require("OOP.Class");

local Color = class();
-- ...

-- At this point, there is no class named "Point3D", but it can still be inherited.
local Vertex = class("Vertex","Point3D",Color);
-- ...
-- The Vertex object constructed at this stage has only the features of Color and Vertex itself.
-- ...

-- At this point, there is no class named "Point" either, but it can be inherited.
local Point3D = class("Point3D","Point");
-- ...
-- The Point3D object constructed at this stage has only its own features.
-- The Vertex object constructed at this stage has only the features of Color/Point3D and Vertex itself, no features of Point.
-- ...

local Point = class("Point");
-- ...
-- At this point both Vertex and Point3D have all base class features.
```

## Access Permissons

In particular,it should be noted that all access permissons rules also apply to [Standard Meta-methods](#standard-meta-methods) and [Properties](#properties).

### public
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

### protected
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

### private
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

### static

When a member is modified as static,means that the member can't be accessed by using object, but only by using class.\
Spcifically,constructor and destructor can't be modified by static.
```lua
require("OOP.Class");
local S = class();
-- static member,used to count the total of objects.
S.static.Count = 0;

function S:ctor(x,y)
    S.Count = S.Count + 1;
end

function S:dtor()
    S.Count = S.Count - 1;
end

function S.static.ShowCount()
    print("Count = ".. S.Count);
end

local p1 = S.new(1,2);
S.ShowCount();-- Count = 1
local p2 = S.new();
S.ShowCount();-- Count = 2
p1:delete();
S.ShowCount();-- Count = 1

print(p2.Count);-- nil

-- Raise an error, ShowCount will return nil when accessed using the object.
p2.ShowCount();
```

### const

Member variables modified by constants are not allowed to be modified again;\
member functions modified by constants are not allowed to call non-constant methods or modify any members.
```lua
require("OOP.Class");
local Other = class();
function Other:DoSomething()
end

local TestBase = class();
function TestBase:DoBase()
end

local Test = class(TestBase);
-- The data modified by const is now declared as a constant and can't be changed.
Test.const.data = "123";
Test.change = "change";

local test = Test.new();
print(test.data);-- "123"
function Test.const:ConstFunc()
end
function Test:NonConstFunc()
end
-- The method qualified by constants.
function Test.const:ChangeValue()
    Other.new():DoSomething();-- Allows calling non-const methods of other classes.
    self:ConstFunc();-- Allows calling const methods.
    self:NonConstFunc();-- Raise an error and do not allow calling non-const methods.
    self:DoBase();-- Raising errors and not allowing calls to base class non-const methods.
    self.change = "xxx";-- Raise an error, const methods cannot modify members internally.
end
test:ChangeValue();
-- Raise error,constants can't be changed.
test.data = "321";
-- Raise error,constants can't be changed.
Test.data = "321";
```

### friends
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

### final

#### Non-inheritable
```lua
require("OOP.Class");
-- After a class is modified with final, it is no longer inheritable.
local FinalClass = class.final();
-- ...
local ErrorClass = class(FinalClass);-- Raise error.
```

#### Non-overridable
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

### Combination

public/protected/private/static/constant/final etc. can be used in combination:
```lua
local T = class();
-- A non-overridable public static constant named Type.
T.public.static.const.final.Type = "T_Type";
-- A private constant named data1.
T.private.const.data1 = {
    str = "123",
    int = 123
};

-- Wrong, public/private/protected cannot be more than one at the same time.
T.public.private.protected.data2 = 123;
-- ...
```

### Other Matters

The modifications to ctor and dtor will directly affect the new and delete methods, and in any case, new is necessarily static, e.g:
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
    -- Raise error, new is necessarily a static member,and objects cannot access static members.
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

Use class.raw to force a break in access permissions:
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
    -- Access permissions have now been broken and can access any member.
    return test:GetMyInfo(),test.mySecret;
end);
print(forceBreak());

-- remains inaccessible outside of class.raw.
print(test.mySecret);
```

class.delete and class.default：
```lua
require("OOP.Class");
-- If you don't want Test1 to be constructed,
-- you can assign class.delete to the constructor.
local Test1 = class();
Test1.ctor = class.delete;
local test1 = Test1.new();-- An error was raised, and now the Test1 type cannot be constructed.

-- Classes that inherit from Test1 cannot be constructed either.
local Test2 = class(Test1);
local test2 = Test2.new();-- Raise an error, and the Test2 type cannot be constructed too.

-- For class.default, I think it has no use, it is actually an empty function,
-- it exists only to correspond to the c++ default keyword.
```

Some special qualifying rules:
* Constructors and destructors cannot be modified with static or const;
* Cannot qualify some special methods and members ([Event](#event)/[Imitation Meta-methods](#imitation-meta-methods).etc).

## Properties
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

-- where 'get' means read-only, 'set' means write-only.
-- Associate the XY property with the Point.GetXY method.
Point.get.XY = Point.GetXY;
-- It can also be defined directly as a member function.
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

-- Static properties, accessible only using classes.
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

--Use the property to change the 'y' value.
p.Y = 888;
-- Using GetXY is equivalent to using the XY property.
xy = p:GetXY();
print("X = " .. xy.x);-- X = 3
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
-- Accordingly, write-only property cannot be read.
p3d.XY = {x = 200,y = 300};

-- Access to static properties.
print(Point3D.Count);-- 1
-- Static properties are not accessible through the object.
print(p3d.Count);-- nil
```

## Type judgment
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

## Meta-methods

In LuaOOP,both standard and imitation metamethods can be inherited and overridden.

### Standard Meta-methods
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

-- Metamethods can also be qualified..
function Point.final:__add(another)
    return Point.new(self.x + another.x, self.y + another.y);
end

function Point.const:__tostring()
    return "x = " .. self.x .. ";y = " .. self.y .. ";";
end

-- Use static to qualify the metamethod to make it accessible only through the class.
function Point.static:__call(...)
    return self.new(...);
end

local AnotherPoint = class(Point);
function AnotherPoint:__call()
    return self.x,self.y;
end

local p1 = Point.new(1,2);
local p2 = Point.new(2,3);
-- Call __add
local p3 = p1 + p2;
-- Call static.__call
local p4 = Point(3,4);

-- Call __tostring
print(p1);-- x = 1;y = 2;
print(p2);-- x = 2;y = 3;
print(p3);-- x = 3;y = 5;

print(p4.is() == Point);-- true

-- static.__call inherite from Point.
local ap = AnotherPoint(1000,2000);
-- __call and static.__call are independent of each other.
local x,y = ap();
print(x);-- 1000
print(y);-- 2000

p4();-- Raise an error, __call can only be accessed using class after being qualified by static.
```

### Reserved Meta-methods

The following metamethods are reserved and cannot be customized,and do not change them by setmetatable:
* __index
* __newindex
* __metatable
* __mode

### Imitation Meta-methods

Imitation metamethods are not really metamethods,but just member functions that are similar to metamethods, but they have unique roles and usage.

#### __new

The __new metamethod is used to overload the new operation.Similar to C++,overloading the new operation will only care about what memory is allocated for the object (the default is to allocate a table) and not about the details of the constructor.\
The only three types that can be allocated at the moment are table/userdata/nil.\
The following demonstrates how to allocate table/nil values.See [External Classes And External Objects](#external-classes-and-external-objects) for allocating userdata:
```lua
require("OOP.Class");
local T = class();
T.data = nil;
-- T only accepts construction with numeric types, all other construction parameters return nil.
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

The __delete metamethod is used to overload the delete operation.Similar to C++,overloading the delete operation will only care about how memory is recycled,not the details of the destructor.\
And objects that are allocated as tables and nulls generally do not need to overload the delete operation,their memory will be managed automatically by Lua.\
For objects allocated as userdata, their memory is also managed automatically by Lua, but some userdata may be designed to be of type T**,in which case it may be necessary to implement the __delete meta method to recycle the memory they point to,see [Life Cycle](#life-cycle) for this case.

#### __singleton

The role of the __singleton meta-method is simply to make it easier to implement a singleton,but the meta-method is not necessary and you can take your own implementation if you have a unique one.
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
-- Define __singleton to get a singleton.
function Device:__singleton()
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

-- Raise error, after defining __singleton, new will be protected by default (unless the constructor is pre-specified as private).
local device = Device.new();
```

## External Classes And External Objects

In some cases, the Lua C API is used to register classes that can return userdata types (such as the FILE* type returned by io.open), which have separate meta-tables and construction entries.\
Sometimes we want to extend/inherit such external objects/external classes:

### Extend External Objects
```lua
local __file__ = (arg or {...})[arg and 0 or 2];
local __dir__ = __file__:match("^(.+)[/\\][^/\\]+$");
local __test1__ = __dir__ .. "/test1";
local __test2__ = __dir__ .. "/test2";
--
require("OOP.Class");
local File = class();

-- Extend an external object and simply use the __new meta-method to return that object.
function File.__new(...)
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

local file1 = File.new(__test1__,"w");
local file2 = io.open(__test2__,"w");

print(file1.is(File));-- true
print(File.is(io));-- false

assert(getmetatable(file2) == getmetatable(file1));
assert(file1.MakeContent ~= nil);
file1:write(file1:MakeContent());
-- Although file1 and file2 use the same meta-table,but file2 is not extended by the File type,
-- so file2 cannot access the MakeContent method.
assert(file2.MakeContent == nil);

file1:close();-- FILE* types can access the close method.

-- Because File only extends the returned FILE* type,but does not inherit the FILE* type itself,
-- so it is not possible to access a field that only FILE* can access through the File class.
File.close(file2);-- File cannot access the close method, raising an error.
```

### Inherite External Classes
```lua
local __file__ = (arg or {...})[arg and 0 or 2];
local __dir__ = __file__:match("^(.+)[/\\][^/\\]+$");
local __test__ = __dir__ .. "/test";
--
require("OOP.Class");
-- Unlike directly extending,now inherited io.
local File = class(io);

-- still need to allocate userdata of type FILE*.
function File.__new(...)
    return io.open(...);
end

local file = File.new(__test__,"w");
file:close();
print(file.is(File));-- true
print(File.is(io));-- true

file = File.new(__test__,"w");
File.close(file);-- Now, the close method can also be accessed through File.
```

Sometimes the external class 'cls' inherits from the external class 'base'. If you need to be able to use is to determine this inheritance relationship even after being inherited, implement the Config.ExternalClass.IsInherite function:
```lua
local Config = require("OOP.Config");
Config.ExternalClass.IsInherite = function(cls,base)
    return 'Your code,return a boolean'
end
local LuaCls = class(cls);
local lc = LuaCls.new();
print(lc.is(base));-- true
print(LuaCls.is(base));-- true
```

### Life Cycle

Determine if an external object is available:
```lua
local __file__ = (arg or {...})[arg and 0 or 2];
local __dir__ = __file__:match("^(.+)[/\\][^/\\]+$");
local __test__ = __dir__ .. "/test";
--
local Config = require("OOP.Config");

-- In general it is sufficient to use class.null directly.
-- If there are special needs, you can customize the Config.ExternalClass.Null function to determine whether an external object is available or not.
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

For Lua FILE* types, since their memory is managed by Lua, it is not possible to destroy and recycle memory manually;\
However,for some custom implementations of types that may have T** structures,Lua memory management does not recycle what they really point to, except for the T** pointer.\
Generally,__delete is implemented to destroy C/C++ memory:
```lua
local ExtClass = require("Your external function library");
require("OOP.Class");
local LuaClass = class(ExtClass);
function LuaClass.__new(...)
    return ExtClass.YourMemoryAllocationFunction(...);
end
function LuaClass:__delete()
    ExtClass.YourMemoryReleaseFunction(self);
end
function LuaClass:dtor()
    print("LuaClass is destructed at here.")
end

local obj = LuaClass.new();
print(class.null(obj));-- false
-- The destructor will still be called.
obj:delete();-- "LuaClass is destructed at here."
print(class.null(obj));-- true
```

## Conversion

Sometimes I want to convert an object to the type I specify, which of course can be a duck typing or something else (generally a table or user data):
```lua
local __file__ = (arg or {...})[arg and 0 or 2];
local __dir__ = __file__:match("^(.+)[/\\][^/\\]+$");
local __test__ = __dir__ .. "/test";

local To = class("To");
To.x = 0;
To.y = 0;
function To:PrintXY()
    print("x=".. self.x);
    print("y=".. self.y);
    return self.x,self.y;
end

local convertTo = {x = 1,y = 3};
-- Use class.to to complete the conversion.
class.to(convertTo,To);
local x,y = convertTo:PrintXY();
assert(x == 1);
assert(y == 3);
assert(convertTo.is() == To);

-- There are other forms of calls to class.to.
convertTo = class.to({x = 2,y = 5},"To");
x,y = convertTo:PrintXY();
assert(x == 2);
assert(y == 5);
assert(convertTo.is() == To);

-- Please note that class.to does not guarantee that the conversion is absolutely safe.
convertTo = class.to({x = 2},"To");
local ok = pcall(To.PrintXY,convertTo);
assert(ok == false);

local fileTo = io.open(__test__,"w");
class.to(fileTo,To);
fileTo.x = 2;
fileTo.y = 6;
x,y = fileTo:PrintXY();
assert(x == 2);
assert(y == 6);
assert(fileTo.is() == To);
fileTo:close();
os.remove(__test__);
```

## Event

### Listening
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

-- Use the 'event' reserved word to send events.
-- Send an email to b with the content 123.
-- The parameters correspond to those of the receive function.
event.Email("b","123");

-- Send an event named Any.
event.Any(1,2,3);
event.Any(nil);
event.Any("any",true,-2,function()end,{});
event.Any();
```

### Sort
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

### Reset
```lua
require("OOP.Class");
local Listener = class();
function Listener.handlers:Any()
    print("Responsing 'Any' event->",self);
end

local a = Listener.new();
local b = Listener.new();

a.handlers.Any = function(self)
    print("'a' resets the response to the 'Any' event->",self);
end;

event.Any();
-- Responsing 'Any' event->table: xxxxxxxxxx
-- 'a' resets the response to the 'Any' event->table: xxxxxxxxxx
```

### Disable
```lua
require("OOP.Class");
local Listener = class();
function Listener.handlers:Any()
    print("Responsing 'Any' event.");
end

local a = Listener.new();
-- a-Responsing 'Any' event.
event.Any();

-- Assign false to disable the event response.
a.handlers.Any = false;
event.Any();-- There is no behavior.

-- Assign true to enable the event response.
a.handlers.Any = true;
-- a-Responsing 'Any' event.
event.Any();
```

### Remove
```lua
require("OOP.Class");
local Listener = class();
function Listener.handlers:Any()
    print("Responsing 'Any' event.");
end

local a = Listener.new();
-- Assign nil to remove the event response.
a.handlers.Any = nil;
event.Any();-- There is no behavior.

local b = Listener.new();
-- b-Responsing 'Any' event.
event.Any();
-- b also stops responding to events after destructuring.
b:delete();
event.Any();-- There is no behavior.

-- Anonymous variable.
Listener.new();
-- Anonymous variable-Responsing 'Any' event.
event.Any();
-- At this point the anonymous variable is garbage collected.
collectgarbage();
event.Any();-- There is no behavior.
```

## Enumeration

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
    Seven = enum(7),
    Eight = enum(),
    Nine = enum()
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

## Pure virtual functions

## Override

In general, use **virtual** to declare a pure virtual function.\
Unlike in C++, virtual can **only** be used to declare pure virtual functions.
```lua
require("OOP.Class");
local Interface = class();
Interface.virtual.DoSomething1 = 0;
Interface.virtual.const.DoSomething2 = 0;
Interface.virtual.protected.const.DoSomething3 = 0;

local Test1 = class(Interface);
function Test1:DoSomething1()
    print("DoSomething1");
end
local test1 = Test1.new();--Raise an error,DoSomething2/DoSomething3 has not been overridden and cannot be instantiated.

local Test2 = class(Test1);
-- Note that the qualifiers must be consistent when implementing pure virtual functions,otherwise an error will be raised.
function Test2.const:DoSomething2()
    print("DoSomething2");
    self:DoSomething3();
end
-- You can also use override to qualify the overridden method, which will automatically use the same qualifier.
function Test2.override:DoSomething3()
    print("DoSomething3");
end
local test2 = Test2.new();
test2:DoSomething1();-- "DoSomething1"
test2:DoSomething2();-- "DoSomething2" "DoSomething3"
```

### Signature

When declaring a pure virtual function,you can use the signature to mark the parameters and the value returned by the pure virtual function. \
The meanings of these signatures are given in the following table:
|Sign|  Type  |
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
| *  |  Any   |

Use signatures to declare pure virtual functions:
```lua
require("OOP.Class");
local Interface = class();
-- The first parameter accepts a string or a number.
-- The second argument accepts a table or nuil value.
-- Returns a boolean value and an integer.
Interface.virtual.DoSomething("sn","t?").b.i = 0;

local Test = class(Interface);

-- But does not actually require that the signature be followed, meaning that the signature is merely a hint.
function Test:DoSomething()
    return "something";
end
print(Test.new():DoSomething());-- something
```

## Struct

### Similarities And Differences With Classes
|                      |      Class       |Struct|
|:--------------------:|:----------------:|:----:|
|    Reserved Words    |       class      |struct|
|       Members        |       Yes        | Yes  |
|     Construction     |       Yes        | Yes  |
|     Destruction      |       Yes        |  No  |
|     Inheritance      |       Yes        | Yes  |
|      Properties      |       Yes        |  No  |
|      Efficiency      |      Slower      |Faster|
|     Meta-methods     |       Yes        | Yes  |
|      Qualifiers      |       Yes        |  No  |
|    Instantiation     |    T.new(...)    |T(...)|
|   Name Inheritance   |       Yes        |  No  |
| Delayed Inheritance  |       Yes        |  No  |
|   Event Listening    |       Yes        |  No  |
|Pure Virtual Functions|       Yes        |  No  |
|  Memory Allocation   |table/userdata/nil|table |


### Creating Structs
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

-- Structs can also be inherited(and of course multiple inheritance is possible).
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

## Configuration

### Reserved Words

I don't like the reserved words and function names provided by default (e.g. private, new, etc.) or these reserved words and function names conflict with existing naming, what should I do?

Before executing the ```require("OOP.Class");``` statement, please qualify the named mapping fields in the [Config.lua](OOP/Config.lua) file, some of the default fields are listed below:
```lua
new = "new"
delete = "delete"
ctor = "ctor"
public = "public"
private = "private"
protected = "protected"
```
For example, now:

* **new** renamed to **create**;
* **delete** renamed to **dispose**;
* **ctor** renamed to **\_\_init**;
* Other reserved words are named in their upper case.

The following code will work fine:
```lua
local Config = require("OOP.Config");
Config.new = "create";
Config.delete = "dispose";
Config.ctor = "__init__";
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

For more renameable fields, see the [Config.lua](OOP/Config.lua) file.

### Functionality

The [Config.lua](OOP/Config.lua) file also contains some configuration regarding functionality,as shown in the following table:

|        Field        |    Default    |   Functionality    |
|:-------------------:|:-------------:|:------------------:|
|        Debug        |     true      |Setting it to false improves performance, <br/>but most security checks and access permissions will be disabled.|
|   PropertyBehavior  |       1       |When writing/reading a read/write only property:<br/>0->a warning will be raised;<br/>1->an error will be raised;<br/>2->the operation is allowed;<br/>other values->the operation is ignored.|
|    ConstBehavior    |       1       |When modifying the value of a constant qualifier:<br/>Similar to the 'PropertyBehavior' field.|
|    EnumBehavior     |       1       |When modifying the enumeration:<br/>Similar to the 'PropertyBehavior' field.|
|   StructBehavior    |       2       |When adding fields to a struct object:<br/>Similar to the 'PropertyBehavior' field.|
|   DefaultEnumIndex  |       1       |The default starting value of the enumeration value (kept Lua style by default,starting from 1).|
| GetPropertyAutoConst|     false     |Whether the 'get' property is qualified with const by default (even if the const qualifier is not used).|
|ClearMembersInRelease|     true      |For table objects, whether all key-value pairs are automatically cleared on destruction(only valid in Release mode).|
|    ExternalClass    |      nil      |See [Inherite External Classes](#inherite-external-classes)|
|      HoleLimit      |      15       |Indicates how often the event listener object is recycled, <br/>the higher the value, the lower the frequency.|
|      Language       |      nil      |The language used to print the error message, currently only Chinese and English are supported. <br/>Set to "zh" to switch to Chinese.|

## Compatibility

Try to ensure Lua5.1-Lua5.4 compatibility, but LuaJIT is not tested.