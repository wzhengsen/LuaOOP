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

local function RunTest(d)
    for k,_ in pairs(package.loaded) do
        if k:sub(1,4) == "OOP." or k:sub(1,5) == "Test." then
            package.loaded[k] = nil;
        end
    end

    require("OOP.Config").Debug = d;
    require("OOP.Class");
    local clock = os.clock();

    require("Test.TestSingleClass");
    require("Test.TestInheriteClass");
    require("Test.TestAccessPermission");
    require("Test.TestProperties");
    require("Test.TestIs");
    require("Test.TestMetaMethods");
    require("Test.TestSingleton");
    require("Test.TestExternal");
    require("Test.TestEvent");
    require("Test.TestEnum");
    require("Test.TestVirtual");
    require("Test.TestStruct");

    print(("-- The time taken to run the test in %s mode is "):format(d and "debug" or "release")..(os.clock() - clock));
end

local function main()
    for _,b in pairs({true,false}) do
        RunTest(b);
    end
end

main();