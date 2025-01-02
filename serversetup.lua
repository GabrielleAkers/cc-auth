-- pastebin run H7xctA3Q
local client_files = {
    "https://raw.githubusercontent.com/GabrielleAkers/cc-auth/refs/heads/main/server.lua",
    "https://raw.githubusercontent.com/GabrielleAkers/cc-auth/refs/heads/main/deque.lua",
    "https://raw.githubusercontent.com/GabrielleAkers/cc-auth/refs/heads/main/shared.lua",
    "https://raw.githubusercontent.com/GabrielleAkers/cc-auth/refs/heads/main/utils.lua",
    "https://raw.githubusercontent.com/GabrielleAkers/cc-auth/refs/heads/main/sha.lua",
}

local auth_dir = shell.resolve("./auth_server")
if not fs.isDir(auth_dir) then
    fs.makeDir(auth_dir)
end
shell.setDir(auth_dir)
for _, f in pairs(client_files) do
    shell.run("wget", f)
end

shell.run("server.lua")
