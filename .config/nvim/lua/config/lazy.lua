local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Optional overlay (see lua/config/overlay.lua). Absent on machines without it.
local overlay = require("config.overlay")
overlay.prepend_rtp()

local spec = {}
if overlay.has("lua/corp/base") then
  table.insert(spec, { import = "corp.base" })
end
table.insert(spec, { import = "plugins" })
if overlay.has("lua/corp/plugins") then
  table.insert(spec, { import = "corp.plugins" })
end

require("lazy").setup({
  spec = spec,
  -- Keep the overlay's plugins out of the portable lockfile.
  lockfile = overlay.dir and (overlay.dir .. "/lazy-lock.json") or (vim.fn.stdpath("config") .. "/lazy-lock.json"),
  change_detection = {
    notify = false,
  },
  performance = {
    rtp = {
      -- lazy.nvim resets the runtimepath; keep the overlay on it.
      paths = overlay.dir and { overlay.dir } or {},
    },
  },
})

-- lazy.nvim appended the overlay; move it back to the front so it wins.
overlay.prepend_rtp()
