local config = function(_, opts)
	local ts_main, ts_configs = pcall(function() return require("nvim-treesitter.configs") end)
	if ts_main and ts_configs and ts_configs.setup then
		ts_configs.setup(opts)
	end
end

return {
  {
    "nvim-tree/nvim-web-devicons",
    config = function()
      -- Diagnostic sign icons (replaces deprecated vim.fn.sign_define calls)
      vim.diagnostic.config({
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = "󰅚",
            [vim.diagnostic.severity.WARN]  = "󰀪",
            [vim.diagnostic.severity.HINT]  = "󰌶",
            [vim.diagnostic.severity.INFO]  = "",
          },
        },
      })
    end
  },
  { "williamboman/mason.nvim",
    lazy = true,
    config = function()
      require("mason").setup()
    end
  },
  { "williamboman/mason-lspconfig.nvim",
    lazy = true,
    dependencies = "williamboman/mason.nvim",
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = {
          "lua_ls",
          "pyright",
          "rust_analyzer",
          "gopls",
          "clangd",
          "texlab",
          -- Add other LSP servers you need for your Git workspace
        },
        automatic_installation = true,
        automatic_enable = false,
      })
    end
  },
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
    },
    event = { "BufReadPre", "BufNewFile" },
    opts = function(_, opts)
      local Util = require("util.util")
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      local servers = {}
      local mason_lspconfig = require("mason-lspconfig")
      local available_servers = mason_lspconfig.get_installed_servers()
      for _, server_name in ipairs(available_servers) do
        -- Get default config to extract root_dir/root_markers
        local default_config = vim.lsp.config[server_name]
        local default_root_dir = default_config and default_config.root_dir
        local default_root_markers = default_config and default_config.root_markers

        servers[server_name] = {
          capabilities = capabilities,
          root_dir = function(bufnr, on_dir)
            local fname = vim.api.nvim_buf_get_name(bufnr)
            if Util.lsp_skip(fname) then
              return -- Don't activate for paths handled elsewhere (see util/util.lua)
            end
            
            if type(default_root_dir) == 'function' then
              default_root_dir(bufnr, on_dir)
            elseif type(default_root_dir) == 'string' then
              on_dir(default_root_dir)
            elseif default_root_markers then
              local root = vim.fs.root(bufnr, default_root_markers)
              if root then
                on_dir(root)
              end
            end
          end,
          single_file_support = false,
        }
      end

      return vim.tbl_deep_extend("force", opts, {
        servers = servers,
      })
    end,
    config = function(_, opts)
      for server_name, server_opts in pairs(opts.servers or {}) do
        -- Use Neovim 0.11+ API to configure and enable
        vim.lsp.config(server_name, server_opts)
        vim.lsp.enable(server_name)
      end
    end,
    keys = {
      { "gD", "<cmd>lua vim.lsp.buf.declaration()<cr>", desc = "Goto declaration" },
      { "gW", "<cmd>lua vim.lsp.buf.workspace_symbol()<cr>", desc = "Search for workspace symbol" },
      { "gk", "<cmd>lua vim.lsp.buf.hover()<cr>", desc = "LSP hover" },
      { "K", "<cmd>lua vim.lsp.buf.hover()<cr>", desc = "LSP hover (Shift-K)" },
      { "<leader>rn", "<cmd>lua vim.lsp.buf.rename()<cr>", desc = "Rename word under cursor" },
      { "<leader>ca", "<cmd>lua vim.lsp.buf.code_action()<cr>", desc = "Code Actions" },
      { "gd", "<cmd>lua vim.lsp.buf.definition()<cr>", desc = "Goto definition" },
      { "gi", "<cmd>lua vim.lsp.buf.implementation()<cr>", desc = "Goto implementation" },
      { "gr", "<cmd>lua vim.lsp.buf.references()<cr>", desc = "Show references" },
      { "[d", "<cmd>lua if vim.diagnostic.jump then vim.diagnostic.jump()(-1) else vim.diagnostic.goto_prev() end<cr>", desc = "Goto previous diagnostic" },
      { "]d", "<cmd>lua if vim.diagnostic.jump then vim.diagnostic.jump()(1) else vim.diagnostic.goto_next() end<cr>", desc = "Goto next diagnostic" },
    },
  },
  {
	-- Highlight, edit, and navigate code
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	config = config,
	opts = function(_, opts)
		opts.ensure_installed = opts.ensure_installed or {}
		vim.list_extend(opts.ensure_installed, { "bash", "yaml" })
		return opts
	end,
	dependencies = {
		{
			"nvim-treesitter/nvim-treesitter-textobjects",
			branch = "main",
			config = function()
				require("nvim-treesitter-textobjects").setup({
					select = {
						enable = true,
						lookahead = true,
						keymaps = {
							["aa"] = "@parameter.outer",
							["ia"] = "@parameter.inner",
							["af"] = "@function.outer",
							["if"] = "@function.inner",
							["ac"] = "@class.outer",
							["ic"] = "@class.inner",
						},
					},
					move = {
						enable = true,
						set_jumps = true,
						goto_next_start = {
							["]m"] = "@function.outer",
							["]]"] = "@class.outer",
						},
						goto_next_end = {
							["]m"] = "@function.outer",
							["]["] = "@class.outer",
						},
						goto_previous_start = {
							["[m"] = "@function.outer",
							["[["] = "@class.outer",
						},
						goto_previous_end = {
							["[m"] = "@function.outer",
							["[]"] = "@class.outer",
						},
					},
					swap = {
						enable = true,
						swap_next = {
							["<leader>a"] = "@parameter.inner",
						},
						swap_previous = {
							["<leader>a"] = "@parameter.inner",
						},
					},
				})
			end,
		},
		{
			"nvim-treesitter/nvim-treesitter-context",
			opts = {
				multiline_threshold = 1,
			}
		},
	},
	build = ":TSUpdate",
  }
}
