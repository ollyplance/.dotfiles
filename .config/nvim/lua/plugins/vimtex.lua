return {
  "lervag/vimtex",
  lazy = false, -- VimTeX must be loaded early to initialize fully
  init = function()
    if vim.fn.has("mac") == 1 then
      -- macOS: Skim if installed (supports forward search), else Preview via `open`
      if vim.fn.isdirectory("/Applications/Skim.app") == 1 then
        vim.g.vimtex_view_method = "skim"
      else
        vim.g.vimtex_view_method = "general"
        vim.g.vimtex_view_general_viewer = "open"
        vim.g.vimtex_view_general_options = "@pdf"
      end
    else
      -- Robust override to inject valid DISPLAY variable found on system (:20)
      local sys_display = os.getenv("DISPLAY")
      if sys_display == nil or sys_display == "" then sys_display = ":20" end

      vim.g.vimtex_view_method = "general"
      vim.g.vimtex_view_general_viewer = "env DISPLAY=" .. sys_display .. " evince"
      vim.g.vimtex_view_general_options = "@pdf"
    end
    
    -- Auto-compile on save is enabled by default
    
    -- Filter out noisy/harmless warnings so quickfix doesn't pop up (Matches Overleaf's silent behavior)
    vim.g.vimtex_quickfix_ignore_filters = {
      'LaTeX Font Warning: Font shape',
      'LaTeX Font Warning: Some font shapes',
      'Package fancyhdr Warning: \\footskip is too small',
      'underfull \\hbox',
      'overfull \\hbox',
    }
  end,
}
