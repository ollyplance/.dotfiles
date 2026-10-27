return {
	"nvim-telescope/telescope.nvim",
	event = { "BufRead", "BufNewFile" },
	dependencies = {
		"nvim-lua/plenary.nvim",
		"smartpde/telescope-recent-files",
		{
			"nvim-telescope/telescope-fzf-native.nvim",
			-- NOTE: If you are having trouble with this installation,
			--       refer to the README for telescope-fzf-native for more instructions.
			build = "make",
			cond = function()
				return vim.fn.executable("make") == 1
			end,
		},
	},
	config = function()
		local Util = require("util.util")
		local cfg = {
			defaults = {
				-- buffer_previewer_maker = new_maker,
				path_display = function(opts, path)
					-- Do common substitutions
					path = Util.pretty_path(path)

					-- Do truncation. This allows us to combine our custom display formatter
					-- with the built-in truncation.
					-- `truncate` handler in transform_path memoizes computed truncation length in opts.__length.
					-- Here we are manually propagating this value between new_opts and opts.
					-- We can make this cleaner and more complicated using metatables :)
					local new_opts = {
						path_display = {
							truncate = true,
						},
						__length = opts.__length,
					}
					path = require("telescope.utils").transform_path(new_opts, path)
					opts.__length = new_opts.__length
					return path
				end,
				mappings = {
					i = {
						["<C-u>"] = false,
						["<C-d>"] = false,
						["<C-j>"] = require("telescope.actions").move_selection_next,
						["<C-k>"] = require("telescope.actions").move_selection_previous,
					},
				},
				layout_strategy = "vertical",
				layout_config = {
					vertical = {
						height = 0.95,
					},
				},
			},
			pickers = {
				buffers = {
					show_all_buffers = true,
					sort_mru = true,
					mappings = {
						n = {
							["<c-d>"] = require("telescope.actions").delete_buffer,
						},
						i = {
							["<c-d>"] = require("telescope.actions").delete_buffer,
						},
					},
				},
			},
			extensions = { -- this block is optional, and if omitted, defaults will be used
				stat_files = false,
				-- Ignore common patterns that can show up from other plugins
				ignore_patterns = {
					"/%.git/COMMIT_EDITING$",
					"/%.git/COMMIT_EDITMSG$",
					"/%.git/MERGE_MSG$",
					"/Related_Files$",
					"^term:",
					";#toggleterm#",
				},
				recent_files = {
					-- This is a useful option to speed up Telescope by avoiding the check
					-- for file existence.
					stat_files = false,
					-- Ignore common patterns that can show up from other plugins
					ignore_patterns = {
						"/%.git/COMMIT_EDITING$",
						"/%.git/COMMIT_EDITMSG$",
						"/%.git/MERGE_MSG$",
						"/Related_Files$",
						"^term:",
						";#toggleterm#",
					},
				},
			},
		}
		require("telescope").setup(Util.telescope_config(cfg))
		require("telescope").load_extension("recent_files")
		require("telescope").load_extension("fzf")
	end,
}
