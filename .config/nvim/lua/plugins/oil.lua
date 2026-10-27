return {
	"stevearc/oil.nvim",
	opts = {
		keymaps = {
			["<C-e>"] = { "actions.close", mode = "n" },
			["<C-h>"] = { "actions.close", mode = "n" },
			["<C-l>"] = "actions.refresh",
		},
		view_options = {
			show_hidden = true,
		},
		delete_to_trash = true,
		skip_confirm_for_simple_edits = true,
		lsp_file_methods = {
		    autosave_changes = true,
		},
	},
	dependencies = { "nvim-tree/nvim-web-devicons" }, -- use if you prefer nvim-web-devicons
	lazy = false,
}
