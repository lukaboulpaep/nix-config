vim.keymap.set("n", "<leader>e", "<Cmd>Neotree toggle<CR>", { desc = "Toggle file tree" })
vim.keymap.set("n", "<leader>E", "<Cmd>Neotree reveal<CR>", { desc = "Reveal current file" })
vim.keymap.set("n", "<Esc>", "<Cmd>nohlsearch<CR>", { desc = "Clear search highlight" })

for key, direction in pairs({ h = "left", j = "down", k = "up", l = "right" }) do
  vim.keymap.set("n", "<C-" .. key .. ">", "<C-w>" .. key, { desc = "Focus pane " .. direction })
end

-- Keep H/J/K/L sizing consistent with Hyprland without using its Alt bindings.
-- Ctrl+arrows can also be held down to resize continuously.
for _, resize in ipairs({
  { key = "h", arrow = "Left",  command = "vertical resize -5", desc = "Make pane narrower" },
  { key = "j", arrow = "Down",  command = "resize +2",          desc = "Make pane taller" },
  { key = "k", arrow = "Up",    command = "resize -2",          desc = "Make pane shorter" },
  { key = "l", arrow = "Right", command = "vertical resize +5", desc = "Make pane wider" },
}) do
  for _, key in ipairs({ "<leader>w" .. resize.key, "<C-" .. resize.arrow .. ">" }) do
    vim.keymap.set("n", key, "<Cmd>" .. resize.command .. "<CR>", { desc = resize.desc })
  end
end
vim.keymap.set("n", "<leader>w=", "<C-w>=", { desc = "Equalize pane sizes" })
