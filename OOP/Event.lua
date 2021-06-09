-- Copyright (c) 2021 榆柳松

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


--[[
    A message distributor designed to be as simple as possible,
    which does not need to actively create message types or register message types,
    and which forwards an arbitrary number of parameters as intended, e.g.

    **********
    Sends an event named SocketRecv, carrying 3 parameters.
    Event.SocketRecv(msg,data,otherInfo);

    **********
    Sends an event named WindowClose, carrying 1 parameter.
    Event.WindowClose(true);
]]
local Config = require("OOP.Config");
local BaseClass = require("OOP.Variant.BaseClass");
local IsNull = BaseClass.IsNull;
local HoleLimit = Config.HoleLimit;
local EventPool = {};
local EventOrder = {};

local ipairs = ipairs;
local setmetatable = setmetatable;
local insert = table.insert;
local remove = table.remove;
local pcall = pcall;

local function RemakeObjList(pool,lvl,hole)
 -- Rearrange the list of objects
    -- if the number of holes reaches the limit.
    if lvl == 1 and hole > HoleLimit then
        local newObjHandlers = {};
        local idx = 1;
        for _,info in ipairs(lvl) do
            if info.obj then
                newObjHandlers[idx] = info;
                idx = idx + 1;
            end
        end
        pool.objHandlers = newObjHandlers;
    end
end

local Event = setmetatable({},{
    __index = function(t,k)
        local pool = {
            enabled = true,
            objHandlers = {}
        };
        local order = {};

        EventPool[k] = pool;
        EventOrder[k] = order;
        local EventCallLvl = 0;

        local event = function(...)
            if not pool.enabled then
                return;
            end

            local hole = 0;
            local objHandlers = pool.objHandlers;

            EventCallLvl = EventCallLvl + 1;

            -- Rearrange the obj list if the current calling level is 1
            -- and there is a need to rearrange it.
            if EventCallLvl == 1 and #order > 0 then
                local handlerLen = #objHandlers;
                for _,o in ipairs(order) do
                    for i,info in ipairs(objHandlers) do
                        if info.obj == o.obj then
                            local swapIndex = o.index < 1 and 1 or (o.index > handlerLen and handlerLen or o.index);
                            insert(objHandlers,swapIndex,remove(objHandlers,i));
                            break;
                        end
                    end
                end
                EventOrder[k] = {};
            end

            for _,info in ipairs(objHandlers) do
                local obj = info.obj;
                if IsNull(obj) then
                    -- Specifies that the number of holes is increased when the object is destroyed.
                    hole = hole + 1;
                    info.obj = false;
                elseif info.enabled then
                    local ok,ret = pcall(info.handler,obj,...);
                    if not ok then
                        RemakeObjList(pool,EventCallLvl,hole);
                        EventCallLvl = EventCallLvl - 1;
                        error(ret);
                    end
                    if ret then
                        -- If handler returns true,
                        -- the dispatch of the event is terminated.
                        break;
                    end
                end
            end

            RemakeObjList(pool,EventCallLvl,hole);
            EventCallLvl = EventCallLvl - 1;
        end;
        t[k] = event;
        return event;
    end
})


local Handlers = {};

--[[
    Desc:       令一个实例对象响应某事件名。
                其中，handler的第一个参数，一定会被置为该obj。

                另一个通常的监听响应的方式为：
                -- 即监听SocketRecv事件名。
                function someclass.Handler:OnSocketRecv(msg,data)
                    print(msg .. "&" .. data); -- abc&123
                end

                -- 事件通知调用：
                Event.SocketRecv("abc",123)

    Param:      string      事件名。
                obj         对象。
                handler     响应函数。
]]

---Register an object to respond an event which named "eventName".
---The first parameter of "handler" will be set with the current object.
---
---Another common way of listening for responses is:
---function someclass.Handlers:OnSocketRecv(msg,data)
---    print(msg .. "&" .. data); -- abc&123
---end
---
---Event call:
---Event.SocketRecv("abc",123);
---
---@param eventName string
---@param obj any
---@param handler fun(obj:any,...)
---
function Handlers.On(eventName,obj,handler)
    -- Check or define the event name.
    local _ = Event[eventName];
    table.insert(EventPool[eventName].objHandlers,{
        obj = obj,
        enabled = true,
        handler = handler
    });
end

---Removes the response of an object to an event.
---
---@param eventName string
---@param obj any
---
function Handlers.Remove(eventName,obj)
    -- Check or define the event name.
    local _ = Event[eventName];
    local objHandlers = EventPool[eventName].objHandlers;
    for _,info in ipairs(objHandlers) do
        if info.obj == obj then
            -- Don't remove at here,remove it on Event loop.
            info.obj = false;
            break;
        end
    end
end

---Specifies the order in which an object responds to an event.
---
---@param eventName string
---@param obj any
---@param index integer
---
function Handlers.Order(eventName,obj,index)
    -- Check or define the event name.
    local _ = Event[eventName];
    table.insert(EventOrder[eventName],{
        obj = obj,
        index = index
    });
end

rawset(_G,Config.Handlers,Handlers);
rawset(_G,Config.Event,Event);
return {
    Handlers = Handlers;
};