require("config.review-repository").setup()

require("codediff").setup({
  highlights = {
    line_insert = "DiffAdd",
    line_delete = "DiffDelete",
    char_insert = "DesktopDiffAddText",
    char_delete = "DesktopDiffDeleteText",
  },
  diff = { layout = "side-by-side", filler_text = "" },
  explorer = {
    width = 32,
    focus_on_select = true,
    view_mode = "tree",
    -- Keep each folder level visible, matching Neo-tree's directory structure.
    flatten_dirs = false,
  },
  keymaps = {
    view = {
      focus_explorer = "<leader>rb",
      toggle_explorer = "<leader>rB",
      unstage_hunk = false,
      toggle_layout = "<leader>rt",
      quit = "<leader>rq",
      open_in_prev_tab = false, -- review-navigation reuses unsaved editor buffers.
    },
  },
})

require("review").setup({
  comment_types = {
    note = { icon = "", hl = "ReviewNote" },
    suggestion = { icon = "󰌵", hl = "ReviewSuggestion" },
    issue = { icon = "", hl = "ReviewIssue" },
    praise = { icon = "", hl = "ReviewPraise" },
  },
  -- Keep the working file editable; annotate larger changes for the agent.
  codediff = { readonly = false },
  export = { clipboard = true, clear_on_close = false },
  -- Keep normal editing commands and our LSP mappings available in the diff.
  keymaps = {
    add_comment = "<leader>rn",
    add_note = false,
    add_suggestion = false,
    add_issue = false,
    add_praise = false,
    add_file_comment = "<leader>rf",
    toggle_reviewed = "<leader>rv",
    delete_comment = "<leader>rd",
    edit_comment = "<leader>re",
    next_file = "]f",
    prev_file = "[f",
    toggle_file_panel = false,
    list_comments = "<leader>rl",
    export_clipboard = "<leader>ry",
    send_sidekick = false,
    clear_comments = "<leader>rx",
    popup_cancel = "<C-q>",
    close = "<leader>rq",
    toggle_readonly = "<leader>rR",
    show_help = "<leader>r?",
  },
})

require("config.review-comments").setup()
require("config.review-reading").setup()
require("config.review-export").setup()
require("config.review-navigation").setup()
require("config.review-commits").setup()

-- The pinned review.nvim counts only expanded CodeDiff rows. Expand folders
-- before marking/navigating so collapsed files cannot disappear from a review.
local reviewed = require("review.reviewed")
for _, action in ipairs({ "toggle_current", "skip_to_unreviewed" }) do
  local original = reviewed[action]
  reviewed[action] = function(explorer, ...)
    local changed = false
    local function expand(node)
      local children = node:get_child_ids() or {}
      if #children > 0 then
        changed = node:expand() or changed
        for _, id in ipairs(children) do
          expand(explorer.tree:get_node(id))
        end
      end
    end
    for _, node in ipairs(explorer.tree:get_nodes()) do
      expand(node)
    end
    if changed and not explorer.is_hidden then
      explorer.tree:render()
    end
    return original(explorer, ...)
  end
end

vim.keymap.set("n", "<leader>rr", "<Cmd>Review<CR>", { desc = "Review repository changes" })
vim.keymap.set("n", "<leader>rc", "<Cmd>Review commits<CR>", { desc = "Review commits" })

-- review.nvim installs buffer-local maps in the diff panes. Reuse their keys
-- for global fallbacks so comments also work in ordinary files and the sidebar.
local keys = require("review.config").get().keymaps
vim.keymap.set("n", keys.add_comment, function() require("review.comments").add_with_menu() end, { desc = "Add review comment (pick type)" })
vim.keymap.set("x", keys.add_comment, ":<C-u>lua require('review.comments').add_for_range()<CR>", { desc = "Comment on selected text" })
vim.keymap.set("n", keys.add_file_comment, function() require("review.comments").file_comment() end, { desc = "Add or edit whole-file comment" })
vim.keymap.set("n", "<leader>rF", require("config.review-comments").list_file, { desc = "List comments for this file" })
vim.keymap.set("n", keys.edit_comment, "<Cmd>Review edit<CR>", { desc = "Edit review comment" })
vim.keymap.set("n", keys.delete_comment, "<Cmd>Review delete<CR>", { desc = "Delete review comment" })
vim.keymap.set("n", keys.list_comments, "<Cmd>Review list<CR>", { desc = "List review comments" })
vim.keymap.set("n", keys.export_clipboard, "<Cmd>Review export<CR>", { desc = "Choose template and edit review export" })
vim.keymap.set("n", keys.clear_comments, "<Cmd>Review clear<CR>", { desc = "Archive comments and reset review" })
vim.keymap.set("n", "<leader>rX", require("config.review-notes").archive, { desc = "Archive comments; keep reviewed files" })

-- review.nvim only maps the diff buffers. In the sidebar, act on the row
-- under the cursor instead of the file that happened to be open previously.
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("DesktopReviewSidebar", { clear = true }),
  pattern = "codediff-explorer",
  callback = function(event)
    vim.keymap.set("n", keys.toggle_reviewed, function()
      local explorer = require("review.hooks").get_explorer(vim.api.nvim_get_current_tabpage())
      if not explorer then
        return
      end
      local node = explorer.tree:get_node(vim.api.nvim_win_get_cursor(0)[1])
      if not node or not node.data or node.data.type then
        return
      end
      -- CodeDiff updates its selection synchronously before loading the diff.
      explorer.on_file_select(node.data)
      require("review.reviewed").toggle_current(explorer)
    end, { buffer = event.buf, desc = "Toggle selected file reviewed" })
  end,
})
