local utils = require("utils")

local version_file = "https://raw.githubusercontent.com/GabrielleAkers/cc-auth/refs/heads/main/.version"
local update_check = function(is_client)
    print("checking for updates")
    local version = http.get(version_file).readLine()
    local check_file = shell.resolve("./.version")
    local need_update = false
    if not fs.exists(check_file) then
        need_update = true
    else
        local f = fs.open(check_file, "r")
        if f.readLine() ~= version then
            need_update = true
        end
        f.close()
    end
    if need_update then
        print("need to update")
        local pwd = shell.dir()
        if string.find(pwd, "/auth") then
            fs.move(pwd, shell.resolve("../_auth"))
            shell.setDir(shell.resolve(".."))
            if is_client then
                shell.run("pastebin run RFGYnp5J")
            else
                shell.run("pastebin run KGxmMfx9")
                fs.move(shell.resolve("../_auth/persistence"), shell.resolve("."))
            end
            fs.delete(shell.resolve("../_auth"))
        else
            shell.setDir(shell.resolve("/"))
            if is_client then
                shell.run("pastebin run RFGYnp5J")
            else
                shell.run("pastebin run KGxmMfx9")
                fs.move(shell.resolve(pwd .. "/persistence"), shell.resolve("."))
                fs.delete(shell.resolve(pwd .. "/persistence"))
            end
        end
        local f = fs.open(check_file, "w+")
        f.write(version)
        f.close()
    else
        print("no update needed")
    end
end

local tw, th = term.getSize()

local protocol = "auth"
local domain = "tuah"

local session_length = 1800000

local server_utc_hour_offset = -6
local server_timezone = "CDT"

local destruct = function(tbl, ...)
    local insert = table.insert
    local values = {}
    for _, name in ipairs { ... } do
        insert(values, tbl[name])
    end
    return unpack(values)
end

local load_libs = function(lib_paths, ...)
    local _libs = {}
    for k, v in pairs(lib_paths) do
        if not fs.exists(shell.resolve("./" .. k .. ".lua")) then
            shell.run("wget", v)
        end
        _libs[k] = require(k)
    end
    return destruct(_libs, ...)
end

local parse_msg = function(evt)
    local msg, sender = evt[3], evt[2]
    local evt_sep_idx = string.find(msg, "|")
    if evt_sep_idx == nil then error("Invalid message format") end
    local parsed = {
        ["evt"] = string.sub(msg, 1, evt_sep_idx),
        ["data"] = textutils.unserialise(string.sub(msg, evt_sep_idx + 1)),
        ["sender"] = sender
    }
    return parsed
end

local clean_exit = function()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1, 1)
    return 0
end

local events = {
    login = "login|",
    bad_login = "bad_login|",
    update_info = "update_info|",
    send_identity = "identity|",
    session_timeout = "session_timeout|",
    refresh_session = "refresh_session|",
    invalid_token = "invalid_token|",
    valid_token = "valid_token|",
    check_token = "check_token|",
    user_doesnt_exist = "user_doesnt_exist|",
    logout = "logout|"
}

local events_valuemapped = {}
for k, v in pairs(events) do
    events_valuemapped[v] = k
end

local send_msg = function(event, payload, id)
    if not events_valuemapped[event] then error("Unrecognized event type " .. event) end
    rednet.send(id, event .. textutils.serialise(payload), protocol)
end

if not rednet.isOpen() then
    peripheral.find("modem", rednet.open)
end

return {
    update_check = update_check,
    protocol = protocol,
    domain = domain,
    server_utc_hour_offset = server_utc_hour_offset,
    server_timezone = server_timezone,
    destruct = destruct,
    load_libs = load_libs,
    parse_msg = parse_msg,
    send_msg = send_msg,
    events = events,
    clean_exit = clean_exit,
    tw = tw,
    th = th,
    session_length = session_length,
    round = utils.round,
    clamp = utils.clamp,
    pagify = utils.pagify,
    get_sorted_keys = utils.get_sorted_keys,
    first_to_upper = utils.first_to_upper,
    random_id = utils.random_id
}
