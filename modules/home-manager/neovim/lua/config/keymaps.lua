vim.keymap.set("n", "<leader>e", "<Cmd>Neotree toggle<CR>", { desc = "Toggle file tree" })
vim.keymap.set("n", "<leader>E", "<Cmd>Neotree reveal<CR>", { desc = "Reveal current file" })
vim.keymap.set("n", "<Esc>", "<Cmd>nohlsearch<CR>", { desc = "Clear search highlight" })

for key, direction in pairs({ h = "left", j = "down", k = "up", l = "right" }) do
  vim.keymap.set("n", "<C-" .. key .. ">", "<C-w>" .. key, { desc = "Focus pane " .. direction })
end
