local util = require "luci.util"
local uloop = require "uloop"

local stm = require "tsmstm.stm"

local timer = {}
timer.service_name = "Tsmstm"

function timer:start()
    timer.reset_1:set(timer.reset_delays["1_UNPOLL_GSM"])
end


--[[    Сценарий работы ]]
--[[
        ПЕРЕПОДКЛЮЧЕНИЕ МОДМА К USB-порту для поиска Сим-карты
        ------------------------------------------------------
        1. Включить режим "Занят"
        2. Поднять событие "GSM_RESET_STARTED"
        3. Отправить сервису Tsmodem команду отключиться от /dev/ttyUSB
        4. Запустить последовательность команд STM32:
        4.1 ~0:SIM.EN=0
        4.2 ~0:SIM.EN=1
        4.3 ~0:SIM.PWR=0
        5. Поднять событие "GSM_RESET_FINISHED"
        6. Переключить режим "Занят" в режим "Свободен"

]]


--[[ Step-by-step delays of resetting USB-modem ]]
timer.reset_delays = {
    ["1_UNPOLL_GSM"] = 100,     -- Stop modem polling since ubus call tsmodem.driver do_switch runs
    ["2_SIM_EN_0"] = 2000,
    ["3_SIM_EN_1"] = 2000,
    ["4_SIM_PWR_0"] = 2000,
    ["5_POLL_GSM"] = 2000,
    ["6_COMPLETE_RESET"] = 200
}


--[[-------------------------------
         RESETTING PROCESS
-----------------------------------]]

----------------------
function do_reset_1()
----------------------
    util.ubus("tsmodem", "unpoll", {service="tsmstm"})
    timer.reset_2:set(timer.reset_delays["2_SIM_EN_0"])
end
timer.reset_1 = uloop.timer(do_reset_1)

----------------------
function do_reset_2()
----------------------
    local comm = "~0:SIM.EN=0"
    stm:send(comm)
    timer.reset_3:set(timer.reset_delays["3_SIM_EN_1"])
end
timer.reset_2 = uloop.timer(do_reset_2)

----------------------
function do_reset_3()
----------------------
    local comm = "~0:SIM.EN=1"
    stm:send(comm)
    timer.reset_4:set(timer.reset_delays["4_SIM_PWR_0"])
end
timer.reset_3 = uloop.timer(do_reset_3)

----------------------
function do_reset_4()
----------------------
    local comm = "~0:SIM.PWR=0"
    stm:send(comm)
    timer.reset_5:set(timer.reset_delays["5_POLL_GSM"])
end
timer.reset_4 = uloop.timer(do_reset_4)

----------------------
function do_reset_5()
----------------------
    util.ubus("tsmodem", "poll", {})
    timer.reset_6:set(timer.reset_delays["6_COMPLETE_RESET"])
end
timer.reset_5 = uloop.timer(do_reset_5)

----------------------
function do_reset_6()
----------------------
    -- Some staff
end
timer.reset_6 = uloop.timer(do_reset_6)


return timer