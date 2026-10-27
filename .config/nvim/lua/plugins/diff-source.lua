return {
	{
		"echasnovski/mini.diff",
		event = { "BufReadPost", "BufNewFile" },
		config = function()
			local mini_diff = require("mini.diff")

			mini_diff.setup({
				view = {
					style = "sign",
					signs = { add = "┃", change = "┃", delete = " " },
				},
				-- An overlay may replace this spec's `config` with a multi-VCS source.
				source = mini_diff.gen_source.git(),
			})
		end,
		keys = {
			{
				"<leader>gj",
				function()
					require("mini.diff").goto_hunk("next")
				end,
				desc = "Jump to next hunk",
			},
			{
				"<leader>gk",
				function()
					require("mini.diff").goto_hunk("prev")
				end,
				desc = "Jump to previous hunk",
			},
			{
				"<leader>gp",
				function()
					require("mini.diff").toggle_overlay()
				end,
				desc = "Toggle hunk overlay",
			},
		},
	},
}
