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

--[[
    A message distributor designed to be as simple as possible,
    which does not need to actively create message types or register message types,
    and which forwards an arbitrary number of parameters as intended, e.g.

    **********
    Sends an event named SocketRecv, carrying 3 parameters.
    event.SocketRecv(msg,data,otherInfo);

    **********
    Sends an event named WindowClose, carrying 1 parameter.
    event.WindowClose(true);
]]
local Config = require("OOP.Config");
local class = require("OOP.BaseClass");
local null = class.null;
local HoleLimit = Config.HoleLimit;
local EventPool = {};
local EventOrder = {};
local WeakTable = {__mode = "v"};

local ipairs = ipairs;
local setmetatable = setmetatable;
local insert = table.insert;
local remove = table.remove;
local pcall = pcall;
local rawequal = rawequal;

local function RemakeObjList(pool,lvl,hole)
    -- Rearrange the list of objects
    -- if the number of holes reaches the limit.
    if lvl == 1 and hole > HoleLimit then
        local idx = 1;
        for key,info in ipairs(pool) do
            if info.obj then
                idx = idx + 1;
            end
            pool[key] = nil;
            pool[idx] = info;
        end
    end
end

local event = setmetatable({},{
    __index = function(t,k)
        local pool = {};
        local order = {};

        EventPool[k] = pool;
        EventOrder[k] = order;
        local EventCallLvl = 0;

        local e = function(...)
            local hole = 0;

            EventCallLvl = EventCallLvl + 1;

            -- Rearrange the obj list if the current calling level is 1
            -- and there is a need to rearrange it.
            if EventCallLvl == 1 and #order > 0 then
                local handlerLen = #pool;
                for _,o in ipairs(order) do
                    for i,info in ipairs(pool) do
                        if rawequal(info.obj,o.obj) then
                            local idx = o.index;
                            if idx == 0 then
                                idx = 1;
                            elseif idx > handlerLen then
                                idx = handlerLen;
                            elseif idx < 0 then
                                local newIdx = idx + 1 + handlerLen;
                                idx = newIdx <= 0 and 1 or newIdx;
                            end
                            insert(pool,idx,remove(pool,i));
                            break;
                        end
                    end
                end
                for key,_ in pairs(order) do
                    order[key] = nil;
                end
            end

            for _,info in ipairs(pool) do
                local obj = info.obj;
                local handler = info.handler;
                if not obj or null(obj) then
                    -- Specifies that the number of holes is increased when the object is destroyed.
                    hole = hole + 1;
                    info.obj = false;
                elseif info.enabled and handler then
                    local ok,ret = pcall(handler,obj,...);
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
        t[k] = e;
        return e;
    end
})


local handlers = {};
---Register an object to respond an event which named "eventName".
---The first parameter of "handler" will be set with the current object.
---
---Another common way of listening for responses is:
---function someclass.handlers:SocketRecv(msg,data)
---    print(msg .. "&" .. data); -- abc&123
---end
---
---event call:
---event.SocketRecv("abc",123);
---
---@param eventName string
---@param obj any
---@param handler fun(obj:any,...)
---
function handlers.On(eventName,obj,handler)
    -- Check or define the event name.
    local _ = event[eventName];
    insert(EventPool[eventName],setmetatable({
        obj = obj,
        enabled = true,
        handler = handler
    },WeakTable));
end

---Removes the response of an object to an event.
---
---@param eventName string
---@param obj any
---
function handlers.Remove(eventName,obj)
    -- Check or define the event name.
    local _ = event[eventName];
    for _,info in ipairs(EventPool[eventName]) do
        if rawequal(info.obj,obj) then
            -- Don't remove at here,remove it on event loop.
            info.obj = false;
            break;
        end
    end
end

---Set whether an event is available for an object.
---
---@param eventName string
---@param enabled boolean
---
function handlers.Enabled(eventName,obj,enabled)
    -- Check or define the event name.
    local _ = event[eventName];
    for _,info in ipairs(EventPool[eventName]) do
        if rawequal(info.obj,obj) then
            info.enabled = enabled;
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
function handlers.Order(eventName,obj,index)
    -- Check or define the event name.
    local _ = event[eventName];
    insert(EventOrder[eventName],{
        obj = obj,
        index = index
    });
end

rawset(_G,Config.handlers,handlers);
rawset(_G,Config.event,event);
return {
    handlers = handlers;
};