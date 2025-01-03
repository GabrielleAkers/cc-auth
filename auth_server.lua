local shared = require("auth_shared")
local sha = require("auth_sha")
local events = shared.events

shared.update_check(false)

local lib_paths = {
    ["deque"] = "https://raw.githubusercontent.com/catwell/cw-lua/refs/heads/master/deque/deque.lua",
}

local deque = shared.load_libs(lib_paths, "deque")

local poll_rate = 10 -- 100ths of second

local evt_queue = deque.new()

local run_server = true

local log = function(msg)
    print("[" .. os.time() .. "]" .. " " .. msg)
end

local process_os_events = function()
    local evt
    while true do
        evt = { os.pullEvent() }
        if evt[1] == "rednet_message" then
            if evt[4] == shared.protocol then
                local parsed = shared.parse_msg(evt)
                evt_queue:push_right(parsed)
            end
        elseif evt[1] == "key" then
            if keys.getName(evt[2]) == "q" then
                run_server = false
                rednet.unhost(shared.protocol)
                return shared.clean_exit()
            end
        end
    end
end

local identities, hashes

local write_to_disk = function(file, obj)
    local backups_dir = shell.resolve("./persistence")
    if not fs.isDir(backups_dir) then
        fs.makeDir(backups_dir)
    end
    local identities_file = fs.open(backups_dir .. file, "w")
    identities_file.write(textutils.serialise(obj))
    identities_file.close()
end

local read_from_disk = function(file)
    local backups_dir = shell.resolve("./persistence")
    if not fs.exists(backups_dir .. file) then return {} end
    local identities_file = fs.open(backups_dir .. file, "r")
    local contents = identities_file.readAll()
    identities_file.close()
    return textutils.unserialise(contents)
end

identities = read_from_disk("/identities")
hashes = read_from_disk("/hashes")

local update_identity = function(user, key, val)
    local ident = identities[user]
    if not identities[user] then
        identities[user] = {}
    end
    if not ident then
        ident = {}
    end
    ident[key] = val
    identities[user] = ident
end

local batch_update_identity = function(user, kv)
    for k, v in pairs(kv) do
        update_identity(user, k, v)
    end
    write_to_disk("/identities", identities)
end

local handle_login = function(evt)
    log("login attempt from " .. evt.data.user)
    if hashes[evt.data.user] then
        if hashes[evt.data.user] == sha.hash256(evt.data.user .. evt.data.password) then
            batch_update_identity(evt.data.user, {
                last_pc = evt.sender,
                last_login = os.epoch("utc"),
                token = shared.random_id(16)
            })
            shared.send_msg(events.send_identity, identities[evt.data.user], evt.sender)
        else
            log("failed login attempt from " .. evt.data.user)
            shared.send_msg(events.bad_login, {}, evt.sender)
        end
    else
        hashes[evt.data.user] = sha.hash256(evt.data.user .. evt.data.password)
        write_to_disk("/hashes", hashes)
        batch_update_identity(evt.data.user, {
            user = evt.data.user,
            email = evt.data.user .. "@" .. shared.domain,
            last_pc = evt.sender,
            last_login = os.epoch("utc"),
            token = shared.random_id(16)
        })
        shared.send_msg(events.send_identity, identities[evt.data.user], evt.sender)
    end
end

local handle_update_info = function(evt)
    log("update info for " .. evt.data.user)
    local identity = identities[evt.data.user]

    if os.epoch("utc") - identity.last_login > shared.session_length then
        log("stale session for " .. evt.data.user)
        return shared.send_msg(events.session_timeout, {}, evt.sender)
    end

    if identity.token ~= evt.data.token then
        log("invalid token for " .. evt.data.user)
        batch_update_identity(evt.data.user, {
            token = nil
        })
        return shared.send_msg(events.invalid_token, {}, evt.sender)
    end

    local updated_id = evt.data.updates
    updated_id.last_login = os.epoch("utc")
    updated_id.token = shared.random_id(16)
    batch_update_identity(evt.data.user, updated_id)
    shared.send_msg(events.send_identity, identities[evt.data.user], evt.sender)
end

local handle_refresh_session = function(evt)
    log("refresh session for " .. evt.data.user)

    if os.epoch("utc") - identities[evt.data.user].last_login > shared.session_length then
        log("stale session for " .. evt.data.user)
        return shared.send_msg(events.session_timeout, {}, evt.sender)
    end

    if identities[evt.data.user].token ~= evt.data.token then
        log("invalid token for " .. evt.data.user)
        batch_update_identity(evt.data.user, {
            token = nil
        })
        return shared.send_msg(events.invalid_token, {}, evt.sender)
    end

    batch_update_identity(evt.data.user, { last_login = os.epoch("utc"), token = shared.random_id(16) })
    shared.send_msg(events.send_identity, identities[evt.data.user], evt.sender)
end

local handle_check_token = function(evt)
    log("check token for " .. evt.data.user)

    if not identities[evt.data.user] then
        log("user doesnt exist " .. evt.data.user)
        return shared.send_msg(events.user_doesnt_exist, {}, evt.sender)
    else
        if identities[evt.data.user].token ~= evt.data.token then
            log("invalid token for " .. evt.data.user)
            return shared.send_msg(events.invalid_token, {}, evt.sender)
        end

        if os.epoch("utc") - identities[evt.data.user].last_login > shared.session_length then
            log("stale session for " .. evt.data.user)
            return shared.send_msg(events.invalid_token, {}, evt.sender)
        end

        shared.send_msg(events.valid_token, {}, evt.sender)
    end
end

local handle_logout = function(evt)
    log("logout for " .. evt.data.user)

    if not identities[evt.data.user] then
        log("user doesnt exist " .. evt.data.user)
        return
    end

    if identities[evt.data.user].token ~= evt.data.token then
        log("invalid token for " .. evt.data.user)
        return
    end

    batch_update_identity(evt.data.user, {
        token = nil,
    })
end

local event_handlers = {
    [events.login] = handle_login,
    [events.update_info] = handle_update_info,
    [events.refresh_session] = handle_refresh_session,
    [events.check_token] = handle_check_token,
    [events.logout] = handle_logout
}

local process_events = function()
    local evt, timer
    while true do
        if evt_queue:is_empty() then
            sleep(poll_rate / 100)
        else
            local next_event = evt_queue:pop_left()
            if event_handlers[next_event.evt] then
                event_handlers[next_event.evt](next_event)
            end
        end
    end
end

while run_server do
    rednet.host(shared.protocol, shared.domain)
    parallel.waitForAny(
        process_os_events,
        process_events
    )
end
