local sys  = require "luci.sys"
local uloop = require "uloop"
local util = require "luci.util"

local F = require 'posix.fcntl'
local U = require 'posix.unistd'

local notifier = require "tsmstm.notifier"

local stm = {}
stm.fds = nil                    -- File descriptor
stm.fds_ev = nil
stm.device = "/dev/ttyS1"        -- STM32 port
stm.stdout = ""
stm.command = ""
stm.answer = ""


function stm:init()
	if not stm.fds then
        local initcom = string.format("stty -F %s 1000000", stm.device)
        sys.exec(initcom)
		stm.fds = F.open(stm.device, F.O_RDONLY + F.O_NONBLOCK)
	end
end

function stm:send(command)
	stm.answer = "" -- clear previous result to avoid something like this "result":"OK\nOK\nOK\nOK\n"

 	local stdout = ""
 	local comm = ""
    if (command and #command > 0) then
    	stm.command = command
		comm = string.format('echo "%s" > %s', command, stm.device)
        stm.stdout = sys.exec(comm)
    end
end

function stm:poll()
    if not stm.fds_ev then
        stm.fds_ev = uloop.fd_add(stm.fds, function(ufd, events)
            local message_from_stm = ""
            local ubus_response = {}

            message_from_stm, err, errcode = U.read(stm.fds, 1024)

            if message_from_stm then
               stm.answer = stm.answer .. message_from_stm
            else
               stm.answer = "ERROR"
            end

            if (#stm.answer > 2) then
            	local evname = util.split(stm.command, "=")[1]
	  			notifier:fire(evname, stm.command, tostring(stm.answer))
            end

            

        end, uloop.ULOOP_READ)
    end
end


return stm