-- Keep track of which formatters take too long, to format them async.
local slow_format_filetypes = {}
local conform_opts = {}
local codefmt = {}
local codefmt_opts = {}

local function formatting_configured_for_ft(ft)
	return conform_opts.formatters_by_ft and conform_opts.formatters_by_ft[ft]
end

local function formatting_enabled_in_plugin_for_ft(ft, plugin_opts)
	return plugin_opts.auto_format
		and (plugin_opts.auto_format[ft] or plugin_opts.formatters_by_ft and not plugin_opts.formatters_by_ft[ft])
end

local function formatting_enabled_for_ft(ft)
	return formatting_configured_for_ft(ft)
		and formatting_enabled_in_plugin_for_ft(ft, conform_opts)
		and (not codefmt or formatting_enabled_in_plugin_for_ft(ft, codefmt_opts))
end

return {
	"stevearc/conform.nvim",
	event = "BufWritePre",
	cmd = { "ConformInfo", "Format", "FormatDisable", "FormatEnable" },
	opts = function(_, opts)
		local formatters_by_ft = {
			bzl = { "buildifier" },
			c = { "clang_format" },
			cpp = { "clang_format" },
			javascript = { "prettier" },
			typescript = { "prettier" },
			javascriptreact = { "prettier", lsp_format = "never" },
			typescriptreact = { "prettier" },
			css = { "prettier" },
			scss = { "prettier" },
			html = { "prettier" },
			json = { "prettier" },
			go = { "gofmt" },
			java = { "google-java-format" },
			markdown = { "mdformat" },
			terraform = { "terraform_fmt" },
			sh = { "shfmt" },
			bash = { "shfmt" },
			yaml = { "prettier" },
			yml = { "prettier" },
		}
		local auto_format = {}
		for filetype in pairs(formatters_by_ft) do
			auto_format[filetype] = true
		end
		return vim.tbl_deep_extend("force", opts, {
			default_format_opts = {
				lsp_format = "prefer",
			},
			notify_on_error = true,
			notify_no_formatters = true,
			formatters_by_ft = formatters_by_ft,
			auto_format = auto_format,
			-- Format synchronously at first. But if the LSP or formatter takes too long,
			-- add the filetype to `slow_format_filetypes` and use async formatting.
			format_on_save = function(bufnr)
				if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
					return
				end
				if slow_format_filetypes[vim.bo[bufnr].filetype] then
					return
				end
				if not formatting_enabled_for_ft(vim.bo[bufnr].filetype) then
					return
				end
				local function on_format(err)
					if err and err:match("timeout$") then
						slow_format_filetypes[vim.bo[bufnr].filetype] = true
					end
				end

				return { timeout_ms = 500 }, on_format
			end,
			format_after_save = function(bufnr)
				if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
					return
				end
				if not slow_format_filetypes[vim.bo[bufnr].filetype] then
					return
				end
				if not formatting_enabled_for_ft(vim.bo[bufnr].filetype) then
					return
				end
				return {}
			end,
			-- Custom formatter definitions (an overlay may add more).
			formatters = {},
		})
	end,
	config = function(_, opts)
		vim.api.nvim_set_option_value("formatexpr", "v:lua.require'conform'.formatexpr()", {})

		vim.api.nvim_create_user_command("Format", function(args)
			local range = nil
			if args.count ~= -1 then
				local end_line = vim.api.nvim_buf_get_lines(0, args.line2 - 1, args.line2, true)[1]
				range = {
					start = { args.line1, 0 },
					["end"] = { args.line2, end_line:len() },
				}
			end
			require("conform").format({
				async = true,
				-- Some LSP servers don't support range formatting.
				lsp_format = range and "never" or "prefer",
				range = range,
			})
		end, { range = true })

		vim.api.nvim_create_user_command("FormatDisable", function(args)
			if args.bang then
				-- FormatDisable! will disable formatting just for this buffer
				vim.b.disable_autoformat = true
			else
				vim.g.disable_autoformat = true
			end
		end, {
			desc = "Disable autoformat on save",
			bang = true,
		})

		vim.api.nvim_create_user_command("FormatEnable", function()
			vim.b.disable_autoformat = false
			vim.g.disable_autoformat = false
			if not formatting_configured_for_ft(vim.bo[0].filetype) then
				vim.notify("Formatting enabled but no formatters configured for this filetype", vim.log.levels.WARN)
			elseif not formatting_enabled_for_ft(vim.bo[0].filetype) then
				vim.notify("Formatting enabled but `opts.auto_format` not set for this filetype", vim.log.levels.WARN)
			end
		end, {
			desc = "Re-enable autoformat on save",
		})

		conform_opts = opts
		-- Optional companion formatter plugin (name set by an overlay via
		-- `vim.g.conform_companion_formatter`) that coordinates auto formatting.
		local companion = vim.g.conform_companion_formatter
		codefmt = companion and require("lazy.core.config").plugins[companion] or nil
		codefmt_opts = codefmt and require("lazy.core.plugin").values(codefmt, "opts", false) or {}

		if codefmt and not codefmt_opts.auto_format or not conform_opts.auto_format then
			-- If codefmt is enabled but its `opts.auto_format` disabled,
			-- or if conform.nvim's `opts.formatters_by_ft` is disabled,
			-- disable auto formatting for conform.nvim
			vim.g.disable_autoformat = true
		elseif opts.auto_format and (opts.format_on_save or opts.format_after_save) then
			-- If auto formatting is enabled for conform.nvim, disable it on codefmt.
			vim.g._use_conform_auto_format = true
		end

		require("conform").setup(opts)
	end,
}
