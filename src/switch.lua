local util = require "luci.util"
local uloop = require "uloop"
local stm = require "tsmstm.stm"
local lock = require "tsmstm.lock"

local if_debug = require("tsmstm.util").if_debug

local timer = {}
timer.service_name = "Tsmstm"
timer.new_slotid = ""


--[[    Сценарий работы ]]
--[[
        ПЕРЕКЛЮЧЕНИЕ SIM-слота:
        ------------------------------------------------------
        1. Включить режим "Занят"
        2. Поднять событие "SLOT_CHANGE_STARTED"
        3. Отправить сервису Tsmodem команду отключиться от /dev/ttyUSB
        4. Запустить последовательность команд STM32:
        5.1 ~0:SIM.SEL=1 -- или 0
        5.2 ~0:SIM.EN=0
        5.3 ~0:SIM.EN=1
        5.4 ~0:SIM.PWR=0
        6. Поднять событие "SIM_SLOT_CHANGED"
        7. Переключить режим "Занят" в режим "Свободен"
]]


function timer:start(new_slotid, applink)
    timer.applink = applink
    timer.new_slotid = tostring(new_slotid)
    timer.switch_1:set(timer.switch_delays["1_UNPOLL_GSM"])
end


--[[ Step-by-step delays of switching Sim-card process ]]
timer.switch_delays = {
    ["1_UNPOLL_GSM"] = 100,
    ["2_SIM_SEL"] = 200,
    ["3_SIM_EN_0"] = 2000,
    ["4_SIM_EN_1"] = 2000,
    ["5_SIM_PWR_0"] = 2000,
    ["6_POLL_GSM"] = 2000,      
    ["7_COMPLETE_SWITCH"] = 1000,
}


--[[-------------------------------
         SWITCHING PROCESS
-----------------------------------]]

----------------------
function do_switch_1()
----------------------
    if_debug("Switch process started.")
    if_debug("......................")

    util.ubus("tsmodem", "unpoll", {service="tsmstm"})
    timer.switch_2:set(timer.switch_delays["2_SIM_SEL"])
end
timer.switch_1 = uloop.timer(do_switch_1)

----------------------
function do_switch_2()
----------------------
    local comm = "~0:SIM.SEL=" .. timer.new_slotid
    stm:send(comm)
    timer.switch_3:set(timer.switch_delays["3_SIM_EN_0"])
end
timer.switch_2 = uloop.timer(do_switch_2)

----------------------
function do_switch_3()
----------------------
    local comm = "~0:SIM.EN=0"
    stm:send(comm)
    timer.switch_4:set(timer.switch_delays["4_SIM_EN_1"])
end
timer.switch_3 = uloop.timer(do_switch_3)

----------------------
function do_switch_4()
----------------------
    local comm = "~0:SIM.EN=1"
    stm:send(comm)
    timer.switch_5:set(timer.switch_delays["5_SIM_PWR_0"])
end
timer.switch_4 = uloop.timer(do_switch_4)

----------------------
function do_switch_5()
----------------------
    local comm = "~0:SIM.PWR=0"
    stm:send(comm)
    timer.switch_6:set(timer.switch_delays["6_POLL_GSM"])
end
timer.switch_5 = uloop.timer(do_switch_5)

----------------------
function do_switch_6()
----------------------
    util.ubus("tsmodem", "poll", {})
    timer.switch_7:set(timer.switch_delays["7_COMPLETE_SWITCH"])
end
timer.switch_6 = uloop.timer(do_switch_6)

----------------------
function do_switch_7()
----------------------
    timer.applink.reset_aborted = false -- если перед выполнение switch был прерван reset, то восстанавливаем дальнейшую возможность reset-а
    lock.unlock("", true)
    if_debug("Switch process completed. Slot: " .. tostring(timer.new_slotid))
    if_debug("---------------------------------")
end
timer.switch_7 = uloop.timer(do_switch_7)


return timer