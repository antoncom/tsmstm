local uci = require "luci.model.uci".cursor()
local util = require "luci.util"
local socket = require "socket"

local dbg = {}

dbg.if_debug = function(msg)
	local is_debug = (uci:get("tsmstm", "debug", "enable") == "1")
	local val = ""

	if (is_debug) then
		if (msg and type(msg) == "table") then
			val = util.serialize_json(msg)
		elseif (msg and type(msg) == "string") then
			val = msg:gsub("%c", " ")
		else
			val = msg
		end
		local dt = os.date("*t")  
		local ms = string.match(tostring(os.clock()), "%d%.(%d+)")  
		local d = string.format("%d:%d:%d", dt.hour, dt.min, dt.sec)  

		local socket = require 'socket'  
		local now = socket.gettime()  
		local millis = math.floor((now % 1) * 100)  
		print(string.format('%s.%02d', d, millis) .. " [tsmstm]: " .. tostring(val))
	end
end

return dbg