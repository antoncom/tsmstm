local test = require "tsmstm.teststm.test"
local cjson = require "cjson"
local socket = require "socket"
--require "tsmstm.util"

local function create_bash_tsmstm_ubus_call(method, params)
    return "ubus call tsmodem.stm " .. method .. " '" .. cjson.encode(params) .. "' 2>&1"
end

local function run_bash(bash)
    local ubus_process = io.popen(bash)
    local result = ""
    if ubus_process ~= nil then
        result = ubus_process:read("*a")
        ubus_process:close()
    end
    return result
end

-- add bash timeout check
local function run_bash_with_timeout(bash, timeout_sec)
    local start_time = socket.gettime()
    local ubus_process = io.popen(bash)
    local result = ""

    if ubus_process == nil then
        return nil, "Failed to start process"
    end

    while true do
        local chunk = ubus_process:read(1024)
        if not chunk then break end
        result = result .. chunk

        local elapsed = socket.gettime() - start_time
        if elapsed > timeout_sec then
            ubus_process:close()
            return nil, "Timeout after " .. timeout_sec .. " seconds"
        end
    end

    ubus_process:close()
    return result
end

-- CMD=? func -> get cmd state and status
local function get_cmd_state(command_str)
    local cmd = create_bash_tsmstm_ubus_call("send", { command = command_str })
    local result, err = run_bash_with_timeout(cmd, 3)

    if not result then
        print("Err:", err)
        return nil, nil, err
    end

    --print("Get result:", result)

    local ok, decoded = pcall(cjson.decode, result)
    if not ok then
        return nil, nil, "Err decode JSON"
    end

    local state, status = decoded["answer"]:match("(%d)%s*([A-Z]+)")
    --print("changed state:", state, "status:", status)

    return state, status, nil
end

-- CMD=<state> -> set cmd state
local function set_cmd_state(command_str, state)
    local cmd = create_bash_tsmstm_ubus_call("send", { command = command_str .. state})
    local result, err = run_bash_with_timeout(cmd, 3)
    if not result then
        print("Err:", err)
        return nil, nil, err
    end

    --print("Set result:", result)

    local ok, decoded = pcall(cjson.decode, result)
    if not ok then
        return nil, nil, "Err decode JSON"
    end

    local status = decoded["answer"]:match("%s*([A-Z]+)")
    print("Set status:", status)

    return status, nil
end

-- weelll  wait for (ms) 
local function wait(ms)
    local start_time = socket.gettime() * 1000  
    repeat
        local now = socket.gettime() * 1000
    until (now - start_time) >= ms
end

-- Check: ready for command (ANSW:OK)
test.run(function ()
    local cmd = create_bash_tsmstm_ubus_call("send", { command = "~0"})
    local result = run_bash(cmd)
    test.assert_match("Ready for command test!", "OK", result)
end, test.mode.default, 1)

-- Check: version (ANSW:answer)
-- TODO: add version parse
test.run(function ()
    local cmd = create_bash_tsmstm_ubus_call("send", { command = "~0:SYS.VER"})
    local result = run_bash(cmd)
    test.assert_match("Version test", "answer", result)
end, test.mode.default, 1)

-- Make test's sequence:
-- ->get state -> set state -> get state -> check state
test.run(function ()
    local state, status, err = get_cmd_state("~0:SIM.SEL=?")
    print("Current state:",state, "status:",status)
    local changeState
    if (status == "OK") then 
        if (tonumber(state) == 1) then
            changeState = 0
        else
            changeState = 1
        end
        --print(changeState)
        
        local status, err = set_cmd_state("~0:SIM.SEL=", changeState)
        print("change status:",status)
        -- check changed state

        state, status, err = get_cmd_state("~0:SIM.SEL=?")
        print("changed state:",state, "status:",status)    

    else
        print("Status error!") 
    end
    -- make test!
    test.assert_equal('SIM SEL test!', changeState, tonumber(state))
end, test.mode.default, 1)

-- ~0:SIM.RST TEST
test.run(function ()
    local state, status, err = get_cmd_state("~0:SIM.RST=?")
    print("Current state:",state, "status:",status)
    local changeState
    if (status == "OK") then 
        if (tonumber(state) == 1) then
            changeState = 0
        else
            changeState = 1
        end
        print("change to", changeState)
        
        local status, err = set_cmd_state("~0:SIM.RST=", changeState)
        print("change status:",status)
        
        -- check changed state
        state, status, err = get_cmd_state("~0:SIM.RST=?")
        print("changed state:",state, "status:",status)    

    else
        print("Status error!") 
    end
    -- make test!
    test.assert_equal('SIM RST test!', changeState, tonumber(state))
end, test.mode.default, 1)

print("Wait for it!")
wait(2000)

-- ~0:SIM.PWR TEST
test.run(function ()
    local state, status, err = get_cmd_state("~0:SIM.PWR=?")
    print("Current state:",state, "status:",status)
    local changeState
    if (status == "OK") then 
        if (tonumber(state) == 1) then
            changeState = 0
        else
            changeState = 1
        end
         print("change to", changeState)
        
        local status, err = set_cmd_state("~0:SIM.PWR=", changeState)
        print("change status:",status)
        -- check changed state

        state, status, err = get_cmd_state("~0:SIM.PWR=?")
        print("changed state:",state, "status:",status)    

    else
        print("Status error!") 
    end
    -- make test!
    test.assert_equal('SIM PWR test!', changeState, tonumber(state))
end, test.mode.default, 1)

print("Wait for it!")
wait(2000)

-- ~0:SIM.EN TEST
test.run(function ()
    local state, status, err = get_cmd_state("~0:SIM.EN=?")
    print("Current state:",state, "status:",status)
    local changeState
    if (status == "OK") then 
        if (tonumber(state) == 1) then
            changeState = 0
        else
            changeState = 1
        end
        --print(changeState)
        
        local status, err = set_cmd_state("~0:SIM.EN=", changeState)
        print("change status:",status)
        -- check changed state

        state, status, err = get_cmd_state("~0:SIM.EN=?")
        print("changed state:",state, "status:",status)    

    else
        print("Status error!") 
    end
    -- make test!
    test.assert_equal('SIM EN test!', changeState, tonumber(state))
end, test.mode.default, 1)

----------------------------------------------------------------------------------------------------
test.print_results()

