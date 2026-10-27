vim.api.nvim_set_keymap("n", "<C-e>", ":Oil<CR>", { silent = true, noremap = true })
vim.api.nvim_set_keymap("n", "<C-h>", ":Oil<CR>", { silent = true, noremap = true })

-- [[ Highlight on yank ]]
-- See `:help vim.highlight.on_yank()`
local highlight_group = vim.api.nvim_create_augroup("YankHighlight", { clear = true })
vim.api.nvim_create_autocmd("TextYankPost", {
	callback = function()
		vim.highlight.on_yank()
	end,
	group = highlight_group,
	pattern = "*",
})

vim.api.nvim_create_autocmd({ "BufReadPost", "FileReadPost" }, {
	callback = function()
		vim.cmd.normal("zR")
	end,
})

-- Telescope live_grep in git root
-- Function to find the git root directory based on the current buffer's path
local function find_git_root()
	-- Use the current buffer's path as the starting point for the git search
	local current_file = vim.api.nvim_buf_get_name(0)
	local current_dir
	local cwd = vim.fn.getcwd()
	-- If the buffer is not associated with a file, return nil
	if current_file == "" then
		current_dir = cwd
	else
		-- Extract the directory from the current file's path
		current_dir = vim.fn.fnamemodify(current_file, ":h")
	end

	-- Find the Git root directory from the current file's path
	local git_root = vim.fn.systemlist("git -C " .. vim.fn.escape(current_dir, " ") .. " rev-parse --show-toplevel")[1]
	if vim.v.shell_error ~= 0 then
		print("Not a git repository. Searching on current working directory")
		return cwd
	end
	return git_root
end

-- Custom live_grep function to search in git root
local function live_grep_git_root()
	local git_root = find_git_root()
	if git_root then
		require("telescope.builtin").live_grep({
			search_dirs = { git_root },
		})
	end
end

vim.api.nvim_create_user_command("LiveGrepGitRoot", live_grep_git_root, {})

-- Automation: Start VimTeX + Python Server + Output Local URL (ISOLATED & SECURE)
vim.api.nvim_create_user_command("TexServe", function()
	-- 1. Construct secure sandbox container
	local secure_dir = "/tmp/resume_web_host"
	vim.fn.mkdir(secure_dir, "p")

	-- 2. Propagate current stable PDF to sandbox immediately
	local source_pdf = vim.fn.expand("%:p:r") .. ".pdf"
	if vim.fn.filereadable(source_pdf) == 1 then
		vim.fn.system({ "cp", source_pdf, secure_dir .. "/" })
	end

	-- 3. Activate background compiler
	pcall(function()
		if vim.fn.exists("*vimtex#compiler#start") == 1 then
			vim.cmd("VimtexCompile")
		end
	end)

	-- 4. Fire background python server pointing EXCLUSIVELY to the sandbox
	local port = "8099"
	vim.fn.jobstart({ "python3", "-m", "http.server", port, "--bind", "0.0.0.0" }, { cwd = secure_dir })

	-- 5. Determine routing address
	local handle = io.popen("hostname -f")
	local host = handle:read("*a"):gsub("%s+", "")
	handle:close()
	if host == "" then host = "localhost" end

	-- 6. Prepare direct hyperlink
	local fname = vim.fn.expand("%:t:r") .. ".pdf"
	local url = "http://" .. host .. ":" .. port .. "/" .. fname

	vim.notify("📊 Serving live PDF at: " .. url, vim.log.levels.INFO, { title = "TexServe Activated" })
	vim.fn.setreg('"', url)
end, { desc = "Autogenerate isolated PDF and spin up secure web link" })

-- Provide alternate casings just to be extra friendly
vim.cmd("cabbrev texserve TexServe")
vim.cmd("cabbrev Texserve TexServe")

-- Teardown Automation: Gracefully terminate server and compiler
vim.api.nvim_create_user_command("TexClose", function()
	-- 1. Silence VimTeX compiler
	pcall(function()
		if vim.fn.exists("*vimtex#compiler#stop") == 1 then
			vim.cmd("VimtexStop")
		end
	end)

	-- 2. Cleanse ephemeral staging sandbox
	local sandbox = "/tmp/resume_web_host"
	vim.fn.jobstart({ "rm", "-rf", sandbox })

	-- 3. Annihilate zombie HTTP python processes listening on the active port
	vim.fn.jobstart("lsof -ti :8099 | xargs kill -9 2>/dev/null", { shell = true })

	vim.notify("🔌 Server Terminated & Compile Stopped", vim.log.levels.WARN, { title = "TexServe Dismantled" })
end, { desc = "Hard shutdown of LaTeX compiler and secure server process" })

vim.cmd("cabbrev texclose TexClose")
vim.cmd("cabbrev Texclose TexClose")

-- Post-build listener: Whenever compiler lands successfully, copy new binary to the sandbox
local tex_sync_group = vim.api.nvim_create_augroup("TexSecureSync", { clear = true })
vim.api.nvim_create_autocmd("User", {
	pattern = "VimtexEventCompileSuccess",
	group = tex_sync_group,
	callback = function()
		local sandbox = "/tmp/resume_web_host"
		local current_pdf = vim.fn.expand("%:p:r") .. ".pdf"
		-- If server is currently running (sandbox exists), copy the new artifact instantly
		if vim.fn.isdirectory(sandbox) == 1 and vim.fn.filereadable(current_pdf) == 1 then
			vim.fn.jobstart({ "cp", current_pdf, sandbox .. "/" })
		end
	end,
})

-- Automatic file reload trigger group
local autoreload_group = vim.api.nvim_create_augroup("AutoReloadFiles", { clear = true })
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
	group = autoreload_group,
	callback = function()
		if vim.fn.mode() ~= "c" then
			vim.cmd("checktime")
		end
	end,
})

-- Notify user when file changed on disk (optional but clear)
vim.api.nvim_create_autocmd("FileChangedShellPost", {
	group = autoreload_group,
	callback = function()
		vim.notify("File changed on disk, buffer reloaded.", vim.log.levels.INFO, { title = "AutoRead" })
	end,
})

-- 🚀 ULTIMATE UPGRADE: Indestructible Universal Code Share Linker! 🚀
-- Resolves standard Gerrit/Git repositories instantly (an overlay can add more resolvers,
-- see `share_url` in util/util.lua).
vim.api.nvim_create_user_command("CodeSearchShare", function()
	local file_path = vim.api.nvim_buf_get_name(0)
	if file_path == "" then
		vim.notify("⚠️ No active file context found.", vim.log.levels.WARN)
		return
	end

	local url = ""
	local line_num = vim.api.nvim_win_get_cursor(0)[1]
	local title = "Gerrit Link Ready"

	-- 1. Primary Match: overlay-provided resolver (if any)
	local override_url, override_title = require("util.util").share_url(file_path, line_num)
	if override_url then
		url = override_url
		title = override_title or "Link Ready"
	else
		-- 2. Robust Fallback: Detect and construct Gerrit/Gitiles source viewer links!
		local parent_dir = vim.fn.fnamemodify(file_path, ":h")
		
		-- Run quiet, contained shell commands to extract repository metadata
		local function git_get(cmd)
			local full_cmd = "git -C " .. vim.fn.shellescape(parent_dir) .. " " .. cmd
			local handle = io.popen(full_cmd)
			local result = handle:read("*a"):gsub("%s+", "") -- Read and trim
			handle:close()
			return result
		end

		local remote = git_get("config --get remote.origin.url")
		local sha = git_get("rev-parse HEAD")
		-- Force full-name tracking to get perfect relative path from git root!
		local rel_path = git_get("ls-files --full-name " .. vim.fn.shellescape(file_path))

		-- Only proceed if all telemetry was successfully derived
		if remote ~= "" and sha ~= "" and rel_path ~= "" and not remote:match("^fatal") then
			-- Strip trailing .git to ensure clean Gitiles structure
			remote = remote:gsub("%.git$", "")
			-- Construct standard Gitiles URL pinned to the exact immutable commit!
			url = string.format("%s/+/%s/%s#%d", remote, sha, rel_path, line_num)
		end
	end

	-- 3. Dispatch safely using our unified hardware pipeline!
	if url ~= "" then
		local bin = vim.fn.expand("~/.local/bin/copy-ai-code")
		if vim.fn.executable(bin) == 1 then
			vim.fn.jobstart({ bin, url }, {
				on_exit = function()
					vim.notify("📋 Code link teleported to local clipboard!", vim.log.levels.INFO, { title = title })
				end,
			})
		else
			vim.fn.setreg("+", url) -- Traditional fallback
			vim.notify("📋 URL copied to register (+)", vim.log.levels.WARN)
		end
	else
		vim.notify("⚠️ Could not derive Git context for this file.", vim.log.levels.ERROR)
	end
end, { force = true, desc = "Copy universal CodeSearch or Gerrit link for current line" })
