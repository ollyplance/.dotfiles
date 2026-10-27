vim.keymap.set("i", "jk", "<Esc>", { noremap = true })

vim.keymap.set("n", "Q", "<nop>")

vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-s>", "<C-u>zz")

-- keeps the paste register when pasting
vim.keymap.set("n", "<leader>p", '"_dP', { desc = "Paste without loosing text" })

vim.keymap.set("n", "<leader>u", vim.cmd.UndotreeToggle, { desc = "Toggle Undo Tree" })

-- Keymaps for better default experience
-- See `:help vim.keymap.set()`
vim.keymap.set({ "n", "v" }, "<Space>", "<Nop>", { silent = true })

vim.keymap.set({ "n" }, "n", "nzz")
vim.keymap.set({ "n" }, "N", "Nzz")

-- Remap for dealing with word wrap
vim.keymap.set("n", "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
vim.keymap.set("n", "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })

-- Diagnostic keymaps
vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "go to previous diagnostic message" })
vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "go to next diagnostic message" })
vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, { desc = "open floating diagnostic message" })
vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "open diagnostics list" })

-- Toggle between current and previous buffer
vim.keymap.set("n", "<bs>", "<c-^>zz")

-- Keymaps for better line navigation
vim.keymap.set("n", "H", "^")
vim.keymap.set("n", "L", "$")

vim.keymap.set("n", "<leader>j", "<C-w>j", { desc = "Window Down" })
vim.keymap.set("n", "<leader>k", "<C-w>k", { desc = "Window Up" })
vim.keymap.set("n", "<leader>l", "<C-w>l", { desc = "Window Right" })
vim.keymap.set("n", "<leader>h", "<C-w>h", { desc = "Window Left" })

vim.keymap.set("n", "<leader>xw", function()
  require("trouble").toggle("diagnostics")
end, { desc = "Trouble workspace diagnostics" })

-- Toggle Document Diagnostics (Current Buffer only)
vim.keymap.set("n", "<leader>xd", function()
  require("trouble").toggle({ mode = "diagnostics", filter = { buf = 0 } })
end, { desc = "Trouble document diagnostics" })

-- Toggle Quickfix (Note: name changed to 'qflist' in some contexts, but 'quickfix' usually aliases correctly. 'qflist' is safer for v3)
vim.keymap.set("n", "<leader>xq", function()
  require("trouble").toggle("qflist")
end, { desc = "Trouble quickfix list" })

-- Toggle Loclist
vim.keymap.set("n", "<leader>xl", function()
  require("trouble").toggle("loclist")
end, { desc = "Trouble location list" })

-- Toggle Todo (Requires todo-comments.nvim)
vim.keymap.set("n", "<leader>xt", function()
  require("trouble").toggle("todo")
end, { desc = "Trouble todo comments" })

-- Toggle the standard view (Smart toggle based on last used or default)
vim.keymap.set("n", "<leader>xx", function()
  require("trouble").toggle()
end, { desc = "Trouble toggle" })

vim.keymap.set("n", "<leader>cs", ":CodeSearchShare<cr>", { desc = "Share Codesearch link" })

-- vim.keymap.set("n", "<leader>tt", function()
-- 	require("neotest").run.run()
-- end, { desc = "[T]est [T]est" })
-- vim.keymap.set("n", "<leader>tf", function()
-- 	require("neotest").run.run(vim.fn.expand("%"))
-- end, { desc = "[T]est [F]ile" })
-- vim.keymap.set("n", "<leader>ts", ":Neotest summary<cr>", { desc = "[T]est [S]ummary" })

-- paste without loosing text
vim.keymap.set("v", "p", '"_dP')

-- See `:help telescope.builtin`
vim.keymap.set("n", "<leader>?", function() require("telescope.builtin").oldfiles() end, { desc = "[?] Find recently opened files" })
vim.keymap.set("n", "<leader><space>", function() require("telescope.builtin").buffers() end, { desc = "[ ] Find existing buffers" })
vim.keymap.set("n", "<leader>/", function()
	-- You can pass additional configuration to telescope to change theme, layout, etc.
	require("telescope.builtin").current_buffer_fuzzy_find(require("telescope.themes").get_dropdown({
		winblend = 10,
		previewer = false,
	}))
end, { desc = "[/] Fuzzily search in current buffer" })

-- vim.keymap.set('n', '<leader>gf', require('telescope.builtin').git_files, { desc = 'Search [G]it [F]iles' })
vim.keymap.set("n", "<leader>sh", function() require("telescope.builtin").help_tags() end, { desc = "[S]earch [H]elp" })
-- vim.keymap.set('n', '<leader>sw', require('telescope.builtin').grep_string, { desc = '[S]earch current [W]ord' })
-- vim.keymap.set('n', '<leader>sG', ':LiveGrepGitRoot<cr>', { desc = '[S]earch by [G]rep on Git Root' })
vim.keymap.set("n", "<leader>sR", "<cmd>lua require('telescope').extensions.recent_files.pick()<cr>", { desc = "Search recent files (Telescope)" })
vim.keymap.set("n", "<leader>sd", require("telescope.builtin").diagnostics, { desc = "[S]earch [D]iagnostics" })
vim.keymap.set("n", "<leader>sr", require("telescope.builtin").resume, { desc = "[S]earch [R]esume" })
vim.keymap.set("n", "<leader>gs", require("telescope.builtin").git_stash, { desc = "Search [G]it [S]tash" })
vim.keymap.set("n", "<leader>gg", require("telescope.builtin").git_status, { desc = "Search [G]it Status" })
vim.keymap.set("n", "<leader>gc", require("telescope.builtin").git_commits, { desc = "Search [G]it [C]ommits" })
vim.keymap.set("n", "<leader>gb", require("telescope.builtin").git_branches, { desc = "Search [G]it [B]ranches" })
vim.keymap.set("n", "<leader>st", ":TodoTelescope<cr>", { desc = "Search [T]odo" })

vim.keymap.set("n", "<leader>dh", ":DiffviewFileHistory<cr>", { desc = "[D]iffview [H]istory" })
vim.keymap.set("n", "<leader>dc", ":DiffviewClose<cr>", { desc = "[D]iffview [C]lose" })
vim.keymap.set("n", "<leader>do", ":DiffviewOpen<cr>", { desc = "[D]iffview [O]pen" })

local function set_repo_specific_keymaps()
	local Util = require("util.util")

	if Util.repo_keymaps() then
		-- Handled by the overlay (see util/util.lua)
	elseif Util.is_jj_repo() then
		local has_minidiff, minidiff = pcall(require, "mini.diff")
		if has_minidiff then
			vim.keymap.set("n", "<leader>gj", function() minidiff.goto_hunk("next") end, { desc = "Jump to next hunk", buffer = true })
			vim.keymap.set("n", "<leader>gk", function() minidiff.goto_hunk("prev") end, { desc = "Jump to previous hunk", buffer = true })

			vim.keymap.set("n", "<leader>gr", function()
			  return require("mini.diff").operator("reset") .. 'gh'
			end, { expr = true, remap = true, buffer = true, desc = "Reset hunk under cursor" })

			vim.keymap.set("n", "<leader>gR", function() minidiff.do_hunks(0, "reset") end, { desc = "Reset File", buffer = true })
			vim.keymap.set("n", "<leader>gp", function() minidiff.toggle_overlay() end, { desc = "Toggle hunk overlay", buffer = true })
		end

		vim.keymap.set("n", "<leader>sf", function()
			require("telescope.builtin").find_files({
				cwd = vim.fn.getcwd(),
			})
		end, { buffer = true, desc = "[S]earch [F]iles" })
		vim.keymap.set("n", "<leader>sg", function()
			require("telescope.builtin").live_grep({
				cwd = vim.fn.getcwd(),
			})
		end, { buffer = true, desc = "[S]earch by [G]rep" })
	elseif Util.is_git_repo() then
		-- Fallback for plain git repos
		vim.keymap.set("n", "<leader>sf", function()
			require("telescope.builtin").find_files({
				cwd = vim.fn.getcwd(),
			})
		end, { buffer = true, desc = "[S]earch [F]iles" })
		vim.keymap.set("n", "<leader>sg", function()
			require("telescope.builtin").live_grep({
				cwd = vim.fn.getcwd(),
			})
		end, { buffer = true, desc = "[S]earch by [G]rep" })
	else
		-- Ultimate fallback for standalone directories that aren't repos
		vim.keymap.set("n", "<leader>sf", function()
			require("telescope.builtin").find_files({
				cwd = vim.fn.getcwd(),
			})
		end, { buffer = true, desc = "[S]earch [F]iles" })
		vim.keymap.set("n", "<leader>sg", function()
			require("telescope.builtin").live_grep({
				cwd = vim.fn.getcwd(),
			})
		end, { buffer = true, desc = "[S]earch by [G]rep" })
	end
end

vim.api.nvim_create_autocmd({ "BufEnter", "DirChanged" }, {
	callback = function()
		pcall(set_repo_specific_keymaps)
	end,
})

-- set for current buffer
pcall(set_repo_specific_keymaps)


vim.keymap.set("v", "<C-r>", '"hy:%s/<C-r>h//gc<left><left><left>')

vim.keymap.set("n", "<leader>sm", function()
	local Util = require("util.util")
	local cwd = (vim.uv and vim.uv.cwd()) or vim.fn.getcwd(-1, -1)
	if Util.is_jj_repo() then
		require("util.jj_picker").modified()
	elseif Util.modified_files() then
		-- Handled by the overlay (see util/util.lua)
	elseif Util.is_git_repo() then
		require("telescope.builtin").git_status({ cwd = cwd })
	else
		vim.notify("Not inside a JJ or Git repository", vim.log.levels.WARN)
	end
end, { silent = true, desc = "Search modified files (JJ/Git)" })

-- vim.keymap.set(
-- 	"n",
-- 	"<leader><leader>",
-- 	[[<cmd>lua require('telescope').extensions.recent_files.pick()<CR>]],
-- 	{ silent = true }
-- )

-- vim.keymap.set("n", "<leader>c", require("osc52").copy_operator, { expr = true })
-- vim.keymap.set("n", "<leader>cc", "<leader>c_", { remap = true })
-- vim.keymap.set("v", "<leader>c", require("osc52").copy_visual)

local osc52_copy_script = vim.fn.expand("~/.local/bin/osc52_copy.sh")
local function copy(lines, regtype)
	if vim.fn.executable(osc52_copy_script) == 1 then
		vim.fn.system(osc52_copy_script, table.concat(lines, "\n"))
	else
		-- Fallback: Neovim's built-in OSC52 provider
		require("vim.ui.clipboard.osc52").copy("+")(lines, regtype)
	end
end

local function paste()
	return { vim.fn.split(vim.fn.getreg(""), "\n"), vim.fn.getregtype("") }
end

vim.g.clipboard = {
	name = "osc52",
	copy = { ["+"] = copy, ["*"] = copy },
	paste = { ["+"] = paste, ["*"] = paste },
}

-- Now the '+' register will copy to system clipboard using OSC52
vim.keymap.set("n", "<leader>c", '"+y', { desc = "Copy to clipboard (OSC52)" })
vim.keymap.set("n", "<leader>cc", '"+yy', { desc = "Copy line to clipboard (OSC52)" })

-- Native Treesitter Incremental Selection mappings (Neovim 0.12+)
-- Ctrl+P to start/expand selection, Ctrl+Shift+P (or Ctrl+Q) to shrink.
vim.keymap.set("n", "<C-p>", "van", { remap = true, desc = "Init incremental selection" })
vim.keymap.set("x", "<C-p>", "an", { remap = true, desc = "Expand selection" })
vim.keymap.set("x", "<C-S-p>", "in", { remap = true, desc = "Shrink selection" })
vim.keymap.set("x", "<C-q>", "in", { remap = true, desc = "Shrink selection (fallback)" })
