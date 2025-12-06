local util = require "luci.util"
local ubus = require "ubus"
local uloop = require "uloop"
local sys  = require "luci.sys"

local stm = require "tsmstm.stm"
local switch = require "tsmstm.switch"
local reset = require "tsmstm.reset"
local notifier = require "tsmstm.notifier"
local note = require "tsmstm.note"
local lock = require "tsmstm.lock"


local F = require 'posix.fcntl'
local U = require 'posix.unistd'

local signal = require("posix.signal")
signal.signal(signal.SIGINT, function(signum)

  io.write("\n")
  print("-----------------------")
  print("Tsmstm debug stopped.")
  print("-----------------------")
  io.write("\n")
  os.exit(128 + signum)
end)

local conn = ubus.connect()

function make_ubus()
	local ubus_methods = {
		["tsmstm"] = {
            send = {
                 function(req, msg)
					 	local comm = ""
					 	local stdout = ""

                        if not msg["owner"] then msg["owner"] = "unknown" end
                        if not lock.is_owner_or_set_if_unlocked(msg["owner"]) then
                            resp.status = "busy"
                            resp.msg = "tsmstm is busy"
                            state.conn:reply(req, resp)
                            return
                        end

                        if msg["command"] and msg["owner"]then
                            comm = msg["command"]
							stdout = stm:send(comm)
                        else
                            conn:reply(req, { error = "No command or owner provided"})
                            return
                        end

                        local def_req = conn:defer_request(req)

                        uloop.timer(function()
                            local  res = tostring(stm.answer)
                            stm.answer = ""
                            conn:reply(def_req, { answer = res, command = comm, note = note[comm], ["stdout"] = tostring(stdout) })
                            conn:complete_deferred_request(def_req, 0)

                            lock.unlock("", true)
                         end, 100)
                 end, { command = ubus.STRING, owner = ubus.STRING }
			},
            switch = {
                function(req, msg)
                        local simid

                        if not msg["owner"] then msg["owner"] = "unknown" end
                        if not lock.is_owner_or_set_if_unlocked(msg["owner"]) then
                            resp.status = "busy"
                            resp.msg = "tsmstm is busy"
                            state.conn:reply(req, resp)
                            return
                        end

                        if msg["simid"] then
                            simid = msg["simid"]
                            switch:start(simid)
                        else
                            conn:reply(req, { error = "No valid simid provided."})
                            return
                        end
                        conn:reply(req, { status = "started"})
                        lock.unlock("", true)
                 end, { simid = ubus.STRING, owner = ubus.STRING }
            },
            reset = {
                function(req, msg)
                        if not msg["owner"] then msg["owner"] = "unknown" end
                        if not lock.is_owner_or_set_if_unlocked(msg["owner"]) then
                            resp.status = "busy"
                            resp.msg = "tsmstm is busy"
                            state.conn:reply(req, resp)
                            return
                        end

                        reset:start(simid)
                        conn:reply(req, { status = "started"})
                        lock.unlock("", true)
                 end, { owner = ubus.STRING }
             }
		}
	}
	conn:add( ubus_methods )
    notifier:init(conn, ubus_methods)

end

stm:init()
uloop.init()
make_ubus()
stm:poll()
uloop.run()
