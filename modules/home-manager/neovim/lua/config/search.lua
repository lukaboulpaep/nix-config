local telescope = require("telescope")
local builtin = require("telescope.builtin")

telescope.setup({
  defaults = {
    prompt_prefix = "  ",
    selection_caret = "❯ ",
    sorting_strategy = "ascending",
    layout_config = { prompt_position = "top" },
    path_display = { "truncate" },
  },
  pickers = {
    lsp_references = { jump_type = "never" },
    find_files = { hidden = true, find_command = { "fd", "--type", "f", "--hidden", "--exclude", ".git" } },
    buffers = { sort_mru = true, ignore_current_buffer = true },
  },
})

vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Find files" })
vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "Search project text" })
vim.keymap.set("n", "<leader>fw", builtin.grep_string, { desc = "Search word under cursor" })
vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Find open buffer" })
vim.keymap.set("n", "<leader>fr", builtin.oldfiles, { desc = "Recent files" })
vim.keymap.set("n", "<leader>fh", builtin.help_tags, { desc = "Search help" })
vim.keymap.set("n", "<leader>cd", function()
  builtin.diagnostics({ bufnr = 0 })
end, { desc = "Document diagnostics" })
vim.keymap.set("n", "<leader>cD", builtin.diagnostics, { desc = "All reported diagnostics" })
