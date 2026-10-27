return {
  -- Theme inspired by Atom
  'catppuccin/nvim',
  name = 'catppuccin',
  priority = 1000,
  config = function()
    local catppuccin = require('catppuccin')

    catppuccin.setup({
      flavour = "mocha",
      integrations = {
        mason = true,
        gitsigns = true,
        mini = true,
        treesitter = true,
        which_key = true,
        telescope = true,
        cmp = true,
        native_lsp = {
          enabled = true,
          virtual_text = {
            errors = { "italic" },
            hints = { "italic" },
            warnings = { "italic" },
            information = { "italic" },
          },
          underlines = {
            errors = { "underline" },
            hints = { "underline" },
            warnings = { "underline" },
            information = { "underline" },
          },
          inlay_hints = {
            background = true,
          },
        },
        noice = true,
        notify = true,
        avante = true,
      },
      custom_highlights = function(colors)
        return {
          TelescopeNormal = { bg = colors.base },
          TelescopeBorder = { bg = colors.base, fg = colors.surface1 },
          TelescopePromptNormal = { bg = colors.base },
          TelescopePromptBorder = { bg = colors.base, fg = colors.surface1 },
          TelescopePromptPrefix = { bg = colors.base, fg = colors.pink },
          TelescopeResultsNormal = { bg = colors.base },
          TelescopeResultsBorder = { bg = colors.base, fg = colors.surface1 },
          TelescopePreviewNormal = { bg = colors.base },
          TelescopePreviewBorder = { bg = colors.base, fg = colors.surface1 },
        }
      end,
    })

    vim.cmd.colorscheme 'catppuccin'
  end,
}
