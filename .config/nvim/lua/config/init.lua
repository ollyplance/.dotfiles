require("config.leader")

if vim.g.vscode then
    require("config.vscode")
else
    require("config.lazy")
    require("config.options")
    require("config.mappings")
    require("config.commands")

    -- Optional overlay options/commands/keymaps (see lua/config/overlay.lua).
    if require("config.overlay").has("lua/corp/init.lua") then
        local ok, err = pcall(require, "corp")
        if not ok then
            vim.notify("overlay: " .. tostring(err), vim.log.levels.ERROR)
        end
    end
end
