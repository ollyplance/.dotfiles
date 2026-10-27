-- Set highlight on search
vim.o.hlsearch = false

-- Make line numbers default
vim.wo.number = true

-- Enable mouse mode
vim.o.mouse = "a"

-- Sync clipboard between OS and Neovim.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.o.clipboard = 'unnamedplus'

-- Enable break indent
vim.o.breakindent = true

-- Save undo history
vim.o.undofile = true

-- Case-insensitive searching UNLESS \C or capital in search
vim.o.ignorecase = true
vim.o.smartcase = true

-- Keep signcolumn on by default
vim.wo.signcolumn = "yes"

-- Decrease update time
vim.o.updatetime = 250
vim.o.timeoutlen = 300

-- Set completeopt to have a better completion experience
vim.o.completeopt = "menuone,noselect"

-- NOTE: You should make sure your terminal supports this
vim.o.termguicolors = true

-- Set relative line numbers
vim.o.relativenumber = true

-- highlight the current line
vim.o.cursorline = true

vim.o.pumheight = 5

-- Automatically reload files modified outside neovim
vim.o.autoread = true

-- Self-heal stale / deleted working directories (e.g. after a FUSE remount fails with ENOTCONN)
-- Prevents `vim/fs:837: assertion failed!` and Telescope `attempt to concatenate field 'cwd' (a nil value)`
do
	local uv = vim.uv or vim.loop
	if uv and uv.cwd then
		local orig_cwd = uv.cwd
		local last_valid_cwd = orig_cwd() or vim.env.PWD or vim.env.HOME

		local function heal_cwd()
			local candidates = {}
			if last_valid_cwd and last_valid_cwd ~= "" then
				table.insert(candidates, last_valid_cwd)
			end
			if vim.env.PWD and vim.env.PWD ~= "" then
				table.insert(candidates, vim.env.PWD)
			end
			local ok_buf, buf_name = pcall(vim.api.nvim_buf_get_name, 0)
			if ok_buf and buf_name and buf_name ~= "" and not buf_name:match("^%w+://") then
				local dir = buf_name:match("^(.+)/[^/]+$")
				if dir then
					table.insert(candidates, dir)
				end
			end
			if vim.env.HOME then
				table.insert(candidates, vim.env.HOME)
			end

			for _, dir in ipairs(candidates) do
				local cur = dir
				while cur and cur ~= "" do
					if pcall(uv.chdir, cur) then
						local recovered = orig_cwd()
						if recovered then
							last_valid_cwd = recovered
							return recovered
						end
					end
					local parent = cur:match("^(.+)/[^/]+$")
					if not parent or parent == cur then
						break
					end
					cur = parent
				end
			end
			return vim.env.HOME or "/"
		end

		uv.cwd = function(...)
			local cwd, err, err_name = orig_cwd(...)
			if cwd then
				last_valid_cwd = cwd
				return cwd
			end
			local healed = heal_cwd()
			if healed then
				return healed
			end
			return cwd, err, err_name
		end

		vim.api.nvim_create_autocmd("DirChanged", {
			callback = function()
				local c = orig_cwd()
				if c then
					last_valid_cwd = c
				end
			end,
		})
	end
end
