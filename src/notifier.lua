local ubus = require "ubus"
local util = require "luci.util"
local notes = require "tsmstm.note"

local if_debug = require("tsmstm.util").if_debug


local notifier = {}
notifier.ubus_methods = nil
notifier.conn = nil

function notifier:init(conn, ubus_methods)
    notifier.ubus_methods = ubus_methods
    notifier.conn = conn
end

function notifier:fire(ev_name, comm, res)
    if_debug("Fire: [" .. ev_name .. "]: " .. comm .. " -> " .. res .. " (" .. tostring(notes[comm]) .. ")")
    local ev_body = {
        service = "Tsmstm",
        command = comm,
        result = res,
        note = notes[comm]
    }
	notifier.conn:notify(notifier.ubus_methods["tsmstm"].__ubusobj, ev_name, ev_body)
    --notifier.conn:notify(notifier.ubus_methods["tsmstm"].__ubusobj, "TSMSTM_EVENT", ev_body)
end

return notifier
