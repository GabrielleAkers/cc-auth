-- pastebin run RFGYnp5J
local client_files = {
    "https://raw.githubusercontent.com/GabrielleAkers/cc-auth/refs/heads/main/client.lua",
    "https://raw.githubusercontent.com/GabrielleAkers/cc-auth/refs/heads/main/deque.lua",
    "https://raw.githubusercontent.com/GabrielleAkers/cc-auth/refs/heads/main/shared.lua",
    "https://raw.githubusercontent.com/GabrielleAkers/cc-auth/refs/heads/main/utils.lua",
}

local auth_dir = shell.resolve("./auth")
if not fs.isDir(auth_dir) then
    fs.makeDir(auth_dir)
end
shell.setDir(auth_dir)
for _, f in pairs(client_files) do
    shell.run("wget", f)
end

