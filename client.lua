local shared = require("shared")
local events = shared.events

local timeout = 10 -- seconds

local server_id = rednet.lookup(shared.protocol, shared.hostname)

if not server_id then
    return error("Cant find auth server")
end

local login = function(user, pass, on_invalid)
    shared.send_msg(events.login, { user = user, password = pass }, server_id)
    local id, msg = rednet.receive(shared.protocol, timeout)
    if not id then
        return error("login timeout")
    end
    if id == server_id then
        local login_msg = shared.parse_msg({ [3] = msg, [2] = id })
        if login_msg.evt == events.bad_login then
            return on_invalid()
        end
        if login_msg.evt == events.send_identity then
            return login_msg.data
        end
        print("got here " .. login_msg.evt)
    end
    return error("login failed")
end

local update_info = function(user, token, updates, on_session_timeout, on_invalid_token)
    shared.send_msg(events.update_info, { user = user, updates = updates, token = token }, server_id)
    local id, msg = rednet.receive(shared.protocol, timeout)
    if not id then
        return error("update timeout")
    end
    if id == server_id then
        local update_msg = shared.parse_msg({ [3] = msg, [2] = id })
        if update_msg.evt == events.session_timeout then
            return on_session_timeout()
        end
        if update_msg.evt == events.invalid_token then
            return on_invalid_token()
        end
        if update_msg.evt == events.send_identity then
            return update_msg.data
        end
    end
    return error("update failed")
end

local refresh_session = function(user, token, on_session_timeout, on_invalid_token)
    shared.send_msg(events.refresh_session, { user = user, token = token }, server_id)
    local id, msg = rednet.receive(shared.protocol, timeout)
    if not id then
        return error("refresh timeout")
    end
    if id == server_id then
        local update_msg = shared.parse_msg({ [3] = msg, [2] = id })
        if update_msg.evt == events.session_timeout then
            return on_session_timeout()
        end
        if update_msg.evt == events.invalid_token then
            return on_invalid_token()
        end
        if update_msg.evt == events.send_identity then
            return update_msg.data
        end
    end
    return error("refresh failed")
end

return {
    login = login,
    update_info = update_info,
    refresh_session = refresh_session
}
