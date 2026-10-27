return {
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    init = function()
      vim.o.timeout = true
      vim.o.timeoutlen = 300
    end,
    opts = {
      -- General config defaults work great
      preset = "helix", -- Modern aesthetic
    },
    config = function(_, opts)
      local wk = require("which-key")
      wk.setup(opts)
      wk.add({
        { "<leader>a", group = "Avante (AI) / All" },
        { "<leader>c", group = "Copy/Clipboard" },
        { "<leader>d", group = "Diffview" },
        { "<leader>g", group = "Git/VCS" },
        { "<leader>J", group = "Jujutsu (VCS)" },
        { "<leader>r", group = "Refactor" },
        { "<leader>s", group = "Search" },
        { "<leader>t", group = "Test" },
        { "<leader>x", group = "Trouble/Diagnostics" },
      })
    end
  }
}
