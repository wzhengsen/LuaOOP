-- Copyright (c) 2021 榆柳松
-- https://github.com/wzhengsen/LuaOOP

-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:

-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.

local Config = require("OOP.Config");
local Language = Config.Language;
local LanguageMap = {
    ["%s function can't receive more than one parameters."] = {
        zh = "%s函数不能接受一个以上的参数。"
    },
    ["You can't edit a enumeration."] = {
        zh = "你不能编辑枚举。"
    },
    ["The %s qualifier cannot be used in conjunction with other access qualifiers."] = {
        zh = "修饰符%s不能与其它访问修饰符一起使用。"
    },
    ["%s,%s cannot be used at the same time."] = {
        zh = "%s和%s不能同时使用。"
    },
    ["There is no such qualifier. - %s"] = {
        zh = "没有这个修饰符。 - %s"
    },
    ["You cannot define final members again. - %s"] = {
        zh = "你不能再次定义final成员。 - %s"
    },
    ["The name is unavailable. - %s"] = {
        zh = "该名称不可用。 - %s"
    },
    ["You cannot qualify meta-methods with %s."] = {
        zh = "你不能使用%s修饰元方法"
    },
    ["%s qualifier cannot qualify %s method."] = {
        zh = "修饰符%s不能修饰%s方法。"
    },
    ["A function must be assigned to the property %s."] = {
        zh = "属性%s必须被分配一个函数。"
    },
    ["%s and %s can't be used as property."] = {
        zh = "%s和%s不能被用作属性。"
    },
    ["You cannot use this name \"%s\", which is already used by other class."] = {
        zh = "你不能使用\"%s\"这个名字，它已经被其它类所使用。"
    },
    ["This meta method is not implemented. - %s"] = {
        zh = "该元方法未被实现。 - %s"
    },
    ["attempt to index a %s value."] = {
        zh = "企图索引一个%s值。"
    },
    ["You cannot change the const value. - %s"] = {
        zh = "你不能修改常量值。 - %s"
    },
    ["Attempt to access private members outside the permission. - %s"] = {
        zh = "企图在权限外访问私有成员。 - %s"
    },
    ["Attempt to access protected members outside the permission. - %s"] = {
        zh = "企图在权限外访问保护成员。 - %s"
    },
    ["The key of the object's %s must be a string"] = {
        zh = "对象的%s的键必须是一个字符串。"
    },
    ["The object's %s can only accpet number/function/boolean/nil."] = {
        zh = "对象的%s只能接受数字/函数/布尔/空。"
    },
    ["You can't read a write-only property. - %s"] = {
        zh = "你不能读取只写属性。 - %s"
    },
    ["You can't write a read-only property. - %s"] = {
        zh = "你不能写入只读属性。 - %s"
    },
    ["%s is a reserved word and you can't set it."] = {
        zh = "%s是保留字，你不能设置为值。"
    },
    ["%s reserved word must be assigned to a table."] = {
        zh = "保留字%s必须被分配一个表。"
    },
    ["%s reserved word must be assigned to a function."] = {
        zh = "保留字%s必须被分配一个函数。"
    },
    ["The name of handler function must be a string."] = {
        zh = "响应函数名必须是字符串。"
    },
    ["It is not possible to inherit from the same class repeatedly."] = {
        zh = "不能重复继承同一个类。"
    },
    ["The class/base classes constructor is not accessible."] = {
        zh = "类/基类构造不可访问。"
    },
    ["The class/base classes destructor is not accessible."] = {
        zh = "类/基类析构不可访问。"
    },
    ["Only integers or strings or tables can be used to generate a enumeration."] = {
        zh = "生成枚举时只能使用整数、字符串或表。"
    },
    ["Excess parameters."] = {
        zh = "多余参数。"
    },
    ["The userdata to be retrofited must have a meta table."] = {
        zh = "被改造的用户数据必须具有元表。"
    },
    ["Event handler must be a function."] = {
        zh = "响应事件的必须是函数。"
    },
    ["Unavailable base class type."] = {
        zh = "不可用的基类类型。"
    },
    ["You cannot inherit a final class."] = {
        zh = "你不能继承一个final类。"
    },
    ["The nil value needs to be passed in to destory the object."] = {
        zh = "销毁对象时必须传入一个nil值。"
    },
    ["There is no such property. - %s"] = {
        zh = "没有这个属性。 - %s"
    },
    ["Cannot construct class with unoverridden pure virtual functions. - %s"] = {
        zh = "不能构造类，具有未重写的纯虚函数。 - %s"
    },
    ["%s must be overridden as a function."] = {
        zh = "%s必须被重写为一个函数。"
    },
    ["The pure virtual function %s must be assigned a value of 0."] = {
        zh = "纯虚函数%s必须分配为0值。"
    },
    ["The pure virtual function %s cannot be defined as a static function."] = {
        zh = "纯虚函数%s不能被定义为一个静态函数。"
    },
    ["%s must wrap a function."] = {
        zh = "%s必须包装一个函数。"
    },
    ["This is the function that has been deleted."] = {
        zh = "这是已删除的函数。"
    },
    ["You cannot inherit a nil value."] = {
        zh = "你不能继承一个nil值。"
    },
    ["Cannot call a non-const method on a const method."] = {
        zh = "不能在const方法中调用非const方法。"
    },
    ["A different access qualifier is used when you override pure virtual functions. - %s"] = {
        zh = "在你重写纯虚函数时使用了不同的访问修饰符。- %s"
    },
    ["Only pure virtual functions can be overridden. - %s"] = {
        zh = "只能重写纯虚函数。- %s"
    },
    ["The %s function was overridden with an illegal qualifier."] = {
        zh = "重写%s函数时使用了不合法的修饰符。"
    },
    ["The '...' parameter must be at the end of the list."] = {
        zh = "不定参数必须位于列表的最后。"
    },
    ["The parameter type is not supported. - %s"] = {
        zh = "不被支持的参数类型。 - %s"
    },
    ["Struct be used on a table with metatable."] = {
        zh = "结构体被用于一个具有元表的表。"
    },
    ["The base structure is not a struct type."] = {
        zh = "继承的基结构体不是一个结构体类型。"
    },
    ["The structure must be declared as a table."] = {
        zh = "结构体必须被声明为一个表。"
    },
    ["You are attempting to add a field to the struct."] = {
        zh = "你企图为结构体添加一个字段。"
    },
    ["You are attempting to add a field to the struct and that behavior is prohibited."] = {
        zh = "你企图为结构体添加一个字段，该行为被禁止。"
    },
    ["A non-existent class is used."] = {
        zh = "使用了不存在的类。"
    },
    ["An error occurred when creating the object -"] = {
        zh = "当创建对象时发生错误-"
    }
};

return function (words)
    local map = LanguageMap[words];
    if not map then
        return words;
    end
    return map[Language] or words;
end;