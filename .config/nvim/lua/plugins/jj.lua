return {
  "NicolasGB/jj.nvim",
  cmd = { "J", "Jdiff", "Jhdiff" },
  opts = {
    diff = {
      backend = "diffview",
    },
    editor = {
      auto_insert = true,
      window = {
        type = "floating",
        floating_width = 0.85,
        floating_height = 0.85,
      },
    },
    terminal = {
      window = {
        type = "floating",
        floating_width = 0.9,
        floating_height = 0.9,
      },
    },
  },
  config = function(_, opts)
    require("jj").setup(opts)
  end,
  keys = {
    { "<leader>Jl", "<cmd>J log<cr>", desc = "JJ Log Graph (Interactive)" },
    { "<leader>Js", "<cmd>J status<cr>", desc = "JJ Status" },
    { "<leader>Jd", "<cmd>J desc<cr>", desc = "JJ Describe" },
    { "<leader>Jc", "<cmd>J commit<cr>", desc = "JJ Commit (Desc & New)" },
    { "<leader>Jn", "<cmd>J new<cr>", desc = "JJ New Change" },
    { "<leader>Je", "<cmd>J edit<cr>", desc = "JJ Edit (Checkout)" },
    { "<leader>JD", "<cmd>J diff<cr>", desc = "JJ Diff (Diffview)" },
    { "<leader>Jq", "<cmd>J squash<cr>", desc = "JJ Squash" },
    { "<leader>Ju", "<cmd>J undo<cr>", desc = "JJ Undo" },
    { "<leader>Jr", "<cmd>J redo<cr>", desc = "JJ Redo" },
    { "<leader>Jb", "<cmd>J bookmark<cr>", desc = "JJ Bookmark" },
    { "<leader>JR", "<cmd>J rebase<cr>", desc = "JJ Rebase" },
    { "<leader>Ja", "<cmd>J annotate<cr>", desc = "JJ Annotate (Blame)" },
  },
}
