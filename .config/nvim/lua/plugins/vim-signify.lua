return {
	"mhinz/vim-signify",
	event = { "BufReadPost", "BufNewFile" },
	cond = function()
		local util = require("util.util")
		return util.is_git_repo() and not util.is_work_repo()
	end,
	init = function()
		vim.g.signify_vcs_list = { "hg", "git" }
		vim.g.signify_sign_change = "*"
		vim.g.signify_sign_delete = "-"
	end,
}
