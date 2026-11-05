-- Keep plugin revisions in nvim-pack-lock.json alongside this configuration.
vim.pack.add({
  { src = "https://github.com/nvim-lua/plenary.nvim" },
  { src = "https://github.com/MunifTanjim/nui.nvim" },
  { src = "https://github.com/nvim-tree/nvim-web-devicons" },
  { src = "https://github.com/lewis6991/gitsigns.nvim" },
  { src = "https://github.com/nvim-telescope/telescope.nvim" },
  { src = "https://github.com/nvim-lualine/lualine.nvim" },
  {
    src = "https://github.com/akinsho/bufferline.nvim",
    version = vim.version.range("4"),
  },
  {
    src = "https://github.com/nvim-neo-tree/neo-tree.nvim",
    version = vim.version.range("3"),
  },
})

require("config.neo-tree")
require("config.git")
require("config.buffers")
require("config.search")
