local ubus = require "ubus"
local util = require "luci.util"
local note = require "tsmstm.note"

local conn = ubus.connect()
local notifier = {}
notifier.ubus_methods = nil

function notifier:init(ubus_methods)
    notifier.ubus_methods = ubus_methods
end

function notifier:fire(ev_name, comm, res)
    local ev_body = {
        service = "Tsmstm",
        command = comm,
        result = res,
        note = note[comm]

    }
	conn:notify(notifier.ubus_methods["tsmstm"].__ubusobj, ev_name, ev_body)
end

return notifier
