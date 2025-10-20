local test = require "tsmstm.teststm.test"
local cjson = require "cjson"
local socket = require "socket"

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

local function run_bash_with_timeout(bash, timeout_sec)
    local start_time = socket.gettime()
    local ubus_process = io.popen(bash)
    local result = ""

    if ubus_process == nil then
        return nil, "Failed to start process"
    end

    -- Небольшой хитрый трюк — читаем частями и проверяем время
    while true do
        local chunk = ubus_process:read(1024)
        if not chunk then break end
        result = result .. chunk

        local elapsed = socket.gettime() - start_time
        if elapsed > timeout_sec then
            -- Таймаут истек, закрываем процесс
            ubus_process:close()
            return nil, "Timeout after " .. timeout_sec .. " seconds"
        end
    end

    ubus_process:close()
    return result
end

local function get_sim_state(command_str)
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

local function wait(ms)
    local start_time = socket.gettime() * 1000  -- получаем текущее время в миллисекундах
    repeat
        local now = socket.gettime() * 1000
    until (now - start_time) >= ms
end

-- test RSTSW
test.run(function ()

    local defaultState, status, err = get_sim_state("~0:SIM.RST=?")
    print("start state:",defaultState, "status:",status)   

    local cmd = create_bash_tsmstm_ubus_call("send", { command = "~0:SIM.RSTSW"})
    local result = run_bash(cmd)
    --print(result)
    -- TODO add OK check

    local state, status, err = get_sim_state("~0:SIM.RST=?")
    print("rst state:",state, "status:",status)     

    wait(800)

    local endState, status, err = get_sim_state("~0:SIM.RST=?")
    print("end state:",endState, "status:",status) 

    if tonumber(defaultState) ~= tonumber(state) then
        test.assert_equal('RSTSW test!', tonumber(defaultState), tonumber(endState))
    else 
        print("RSTSW test err")
        test.assert_equal('Надо добавить вывод ошибки ', tonumber(defaultState), endState)
    end
    
end, test.mode.default, 1)

print("Wait for it 2!")
wait(4000)


-- Check: PWR (ANSW:OK)
test.run(function ()
    local defaultState, status, err = get_sim_state("~0:SIM.PWR=?")
    print("start state:",defaultState, "status:",status)   

    local cmd = create_bash_tsmstm_ubus_call("send", { command = "~0:SIM.PWRSW"})
    local result = run_bash(cmd)

    wait(500)

    local State, status, err = get_sim_state("~0:SIM.PWR=?")
    print("end state:",State, "status:",status)   

    test.assert_match_look(
        {
            name = 'Try check PWRSW',
            description = "STM отвечает на команду, но видимого сброса питания не происходит, состояние PWR так же не меняется",
        },
        "OK", 
        result)
end, test.mode.info, 1)

----------------------------------------------------------------------------------------------------
test.print_results()

