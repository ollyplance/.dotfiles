return {
	"lewis6991/gitsigns.nvim",
	event = { "BufReadPost", "BufNewFile" },
	cond = function()
		local util = require("util.util")
		return util.is_git_repo() and not util.is_work_repo() and not util.is_jj_repo()
	end,
	config = function()
		require("gitsigns").setup()
	end,
}
