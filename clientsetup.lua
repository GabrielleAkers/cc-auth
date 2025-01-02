-- pastebin run XHid4qpU
local client_files = {
    ["client"] = "https://raw.githubusercontent.com/GabrielleAkers/cc-auth/refs/heads/main/client.lua",
    ["deque"] = "https://raw.githubusercontent.com/GabrielleAkers/cc-auth/refs/heads/main/deque.lua",
    ["shared"] = "https://raw.githubusercontent.com/GabrielleAkers/cc-auth/refs/heads/main/shared.lua",
    ["utils"] = "https://raw.githubusercontent.com/GabrielleAkers/cc-auth/refs/heads/main/utils.lua",
}

local auth_dir = shell.resolve("./auth")
if not fs.isDir(auth_dir) then
    fs.makeDir(auth_dir)
end
shell.setDir(auth_dir)
for k, f in pairs(client_files) do
    if fs.exists(shell.resolve("./" .. k .. ".lua")) then
        fs.delete(shell.resolve("./" .. k .. ".lua"))
    end
    shell.run("wget", f)
end
