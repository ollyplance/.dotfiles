return {
  -- Set lualine as statusline
  'nvim-lualine/lualine.nvim',
  dependencies = { "catppuccin" },
  -- See `:help lualine.txt`
  opts = {
    options = {
      icons_enabled = false,
      theme = require('catppuccin.utils.lualine')(),
      component_separators = '|',
      section_separators = '',
    },
  },
}
