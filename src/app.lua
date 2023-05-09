local util = require "luci.util"
local ubus = require "ubus"
local uloop = require "uloop"
local sys  = require "luci.sys"


local F = require 'posix.fcntl'
local U = require 'posix.unistd'

local tsmstm = {}
tsmstm.conn = nil                   -- Ubus connection
tsmstm.fds = nil                    -- File descriptor
tsmstm.fds_ev = nil                 -- Event loop descriptor
tsmstm.device = "/dev/ttyS1"        -- STM32 port
tsmstm.answer = ""                  -- Answer message from STM32


function tsmstm:init()
	if not tsmstm.fds then
        local initcom = string.format("stty -F %s 1000000", tsmstm.device)
        sys.exec(initcom)

		tsmstm.fds = F.open(tsmstm.device, F.O_RDONLY + F.O_NONBLOCK)
		tsmstm.conn = ubus.connect()
		if not tsmstm.conn then
			error("Failed to connect to ubus in 'tsmstm' module")
		end
	end
end

function tsmstm:poll()
    if not tsmstm.fds_ev then
        tsmstm.fds_ev = uloop.fd_add(tsmstm.fds, function(ufd, events)
            local message_from_stm = ""
            local ubus_response = {}

            message_from_stm, err, errcode = U.read(tsmstm.fds, 1024)
            if message_from_stm then
                tsmstm.answer = message_from_stm
            else
                tsmstm.answer = "ERROR"
            end

        end, uloop.ULOOP_READ)
    end
end

function tsmstm:make_ubus()
	local ubus_methods = {
		["tsmodem.stm"] = {
            send = {
                 function(req, msg)
                        if msg["command"] then
                            sys.exec(string.format('echo "%s" > %s', msg["command"], tsmstm.device))
                        end
                        local def_req = tsmstm.conn:defer_request(req)
                        uloop.timer(function()
                                tsmstm.conn:reply(def_req, { answer = tsmstm.answer })
                                tsmstm.conn:complete_deferred_request(def_req, 0)
                         end, 100)
                 end, {id = ubus.INT32, msg = ubus.STRING }
			 }
		}
	}
	tsmstm.conn:add( ubus_methods )

end

tsmstm:init()
uloop.init()
tsmstm:make_ubus()
tsmstm:poll()
uloop.run()
