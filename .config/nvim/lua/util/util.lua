local M = {}

function M.get_path()
	-- Trigger self-healing cwd check first in case the working directory vanished
	local cwd = (vim.uv and vim.uv.cwd()) or vim.fn.getcwd() or vim.env.HOME or "/"
	local path = vim.api.nvim_buf_get_name(0)
	if path == "" then
		path = cwd
	end
	-- Strip protocol (e.g. oil://)
	path = path:gsub("^%w+://", "")
	return vim.fn.fnamemodify(path, ":p")
end

function M.is_jj_repo()
	local path = M.get_path()
	local jj = vim.fs.find(".jj", { upward = true, path = path, stop = vim.fn.expand("~") })[1]
	return jj ~= nil
end

function M.is_git_repo()
	local path = M.get_path()
	local git = vim.fs.find(".git", { upward = true, path = path, stop = vim.fn.expand("~") })[1]
	return git ~= nil
end

-- ---------------------------------------------------------------------------
-- Extension points. The defaults give plain git/jj behaviour; an optional
-- overlay (see lua/config/overlay.lua) can override them via `corp.util`.
-- ---------------------------------------------------------------------------

-- True when the current buffer/cwd belongs to a repo whose VCS is handled by
-- the overlay (disables gitsigns/signify and the generic search keymaps).
function M.is_work_repo()
	return false
end

-- Set buffer-local repo-specific keymaps. Return true if handled.
function M.repo_keymaps()
	return false
end

-- Open a "modified files" picker. Return true if handled.
function M.modified_files()
	return false
end

-- Resolve a share URL for `file_path` at `line`. Return `url, title` or nil.
function M.share_url(file_path, line)
	return nil
end

-- Shorten a path for display in pickers.
function M.pretty_path(path)
	return path
end

-- Return true if generic LSP servers must not attach to `fname`.
function M.lsp_skip(fname)
	return false
end

-- Base revision for the jj modified-files picker, or nil for the default.
function M.jj_base_rev(jj_root)
	return nil
end

-- Adjust the telescope setup table before `require("telescope").setup()`.
function M.telescope_config(cfg)
	return cfg
end

local overlay = require("config.overlay")
if overlay.has("lua/corp/util.lua") then
	local ok, ext = pcall(require, "corp.util")
	if ok and type(ext) == "function" then
		ext(M)
	elseif not ok then
		vim.notify("overlay util: " .. tostring(ext), vim.log.levels.ERROR)
	end
end

return M
