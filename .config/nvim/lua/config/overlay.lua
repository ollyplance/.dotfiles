-- Optional machine-specific overlay (e.g. a private work config).
--
-- The overlay lives outside this repo, in `$DOTFILES_CORP_DIR/nvim`
-- (default `~/.dotfiles-corp/nvim`), and has this layout:
--
--   nvim/lua/corp/base/*.lua     lazy.nvim specs imported BEFORE `plugins`
--                                (so the portable specs can override them)
--   nvim/lua/corp/plugins/*.lua  lazy.nvim specs imported AFTER `plugins`
--                                (extend/override the portable specs)
--   nvim/lua/corp/util.lua       optional, returns fun(util) that overrides the
--                                extension points in `util.util`
--   nvim/lua/corp/init.lua       options/commands/keymaps, loaded last
--   nvim/lazy-lock.json          lockfile used instead of the portable one
--
-- When the overlay directory does not exist, everything here is a no-op.
local M = {}

local root = vim.env.DOTFILES_CORP_DIR
if root == nil or root == "" then
	root = vim.fn.expand("~/.dotfiles-corp")
end

---@type string? absolute path of the overlay's nvim dir, or nil when absent
M.dir = nil
if vim.fn.isdirectory(root .. "/nvim") == 1 then
	M.dir = vim.fn.fnamemodify(root .. "/nvim", ":p"):gsub("/$", "")
end

---@param sub string path relative to the overlay dir
---@return boolean
function M.has(sub)
	return M.dir ~= nil and (vim.uv or vim.loop).fs_stat(M.dir .. "/" .. sub) ~= nil
end

-- Make sure the overlay is the first entry of the runtimepath, so its
-- `lua/` modules and `autoload/` files win over plugins.
function M.prepend_rtp()
	if M.dir then
		vim.opt.rtp:remove(M.dir)
		vim.opt.rtp:prepend(M.dir)
	end
end

return M
