vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Defaults; filetype plugins and project .editorconfig files can override these.
vim.opt.expandtab = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.softtabstop = -1

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true
vim.opt.fillchars:append({ eob = " " })
vim.opt.signcolumn = "yes"
vim.opt.termguicolors = true
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.undofile = true
vim.opt.updatetime = 250
vim.opt.completeopt = { "menu", "menuone", "noselect", "popup" }

-- Neo-tree provides directory browsing.
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
