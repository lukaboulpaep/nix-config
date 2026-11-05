local M = {}
local notes = require("config.review-notes")

-- Telescope lists notes with their selection and revision context. The full
-- Markdown comment stays readable in the preview pane.
local function select_comment(items, on_choice, query)
  local actions = require("telescope.actions")
  local state = require("telescope.actions.state")
  local allowed = {}
  for _, item in ipairs(items) do allowed[item.comment.id] = true end
  local function finder()
    return require("telescope.finders").new_table({
      results = vim.tbl_filter(function(note) return allowed[note.id] end, notes.list()),
      entry_maker = function(comment)
        local info = require("review.config").get().comment_types[comment.type]
        local location, status = notes.location(comment), notes.status(comment)
        local revision = comment.revision and (" @" .. comment.revision:sub(1, 10)) or ""
        local display = string.format("%s %s%s [%s, %s%s] %s", info.icon, location, revision,
          comment.type, comment.side or "new", status ~= "" and (", " .. status) or "", comment.text):gsub("%s+", " ")
        return { value = { comment = comment }, display = display, ordinal = display }
      end,
    })
  end
  require("telescope.pickers").new({}, {
    prompt_title = "Review notes",
    layout_strategy = "vertical",
    layout_config = { width = 0.9, height = 0.9, preview_height = 0.6, preview_cutoff = 1 },
    results_title = "Ctrl-e: edit · Ctrl-d: delete",
    default_text = query,
    finder = finder(),
    sorter = require("telescope.config").values.generic_sorter({}),
    previewer = require("telescope.previewers").new_buffer_previewer({
      title = "Comment",
      define_preview = function(self, entry)
        local comment = entry.value.comment
        local lines = { notes.location(comment) .. " · " .. comment.type .. " · " .. (comment.side or "new") .. " side",
          "" }
        if comment.revision then vim.list_extend(lines, { "Snapshot: " .. comment.revision, "" }) end
        local status = notes.status(comment)
        if status ~= "" then vim.list_extend(lines, { "Status: " .. status, "" }) end
        if comment.selection then
          vim.list_extend(lines, { "Selected code:", "" })
          vim.list_extend(lines, vim.split(comment.selection.text, "\n", { plain = true }))
          table.insert(lines, "")
        end
        vim.list_extend(lines, vim.split(comment.text, "\n", { plain = true }))
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
        require("telescope.previewers.utils").highlighter(self.state.bufnr, "markdown")
        require("config.review-reading").wrap_window(self.state.winid)
      end,
    }),
    attach_mappings = function(prompt_bufnr, map)
      local function delete()
        local entry = state.get_selected_entry()
        if not entry then
          return
        end
        notes.delete(entry.value.comment)
        state.get_current_picker(prompt_bufnr):refresh(finder(), { reset_prompt = false })
      end
      local function edit()
        local entry = state.get_selected_entry()
        if not entry then
          return
        end
        local comment = entry.value.comment
        local prompt = state.get_current_line()
        actions.close(prompt_bufnr)
        notes.edit(comment, function()
          -- The popup restores its previous window after 10ms. Reopen after
          -- that so it cannot steal focus from Telescope on save or cancel.
          vim.defer_fn(function()
            select_comment(items, on_choice, prompt)
          end, 20)
        end)
      end
      for _, mode in ipairs({ "i", "n" }) do
        map(mode, "<C-d>", delete, { desc = "Delete selected comment" })
        map(mode, "<C-e>", edit, { desc = "Edit selected comment" })
      end
      map("n", "dd", delete, { desc = "Delete selected comment" })
      map("n", "e", edit, { desc = "Edit selected comment" })
      actions.select_default:replace(function()
        local entry = state.get_selected_entry()
        actions.close(prompt_bufnr)
        if entry then
          on_choice(entry.value)
        end
      end)
      return true
    end,
  }):find()
end

function M.pick(notes, on_choice)
  if #notes == 0 then
    vim.notify("No comments here yet", vim.log.levels.INFO); return
  end
  local items = vim.tbl_map(function(note) return { comment = note } end, notes)
  select_comment(items, function(item) on_choice(item.comment) end)
end

function M.list_file()
  local file = require("review.hooks").get_cursor_position()
  if not file then return end
  M.pick(notes.list(file), require("config.review-navigation").jump)
end

function M.file_note_count()
  local file = require("review.hooks").get_cursor_position()
  local count = 0
  for _, note in ipairs(notes.list(file)) do
    if note.file == file and note.line == 0 then count = count + 1 end
  end
  return count > 0 and ("File notes: " .. count .. " · Space rF") or ""
end

function M.setup()
  if M.configured then
    return
  end
  M.configured = true
  local popup = require("review.popup")
  local open = popup.open
  popup.open = function(...)
    open(...)
    local buf = vim.api.nvim_get_current_buf()
    if vim.bo[buf].filetype ~= "markdown" or vim.api.nvim_win_get_config(0).relative == "" then
      return
    end
    require("config.review-reading").wrap_window(vim.api.nvim_get_current_win())
    local submit = vim.fn.maparg("<C-s>", "n", false, true).callback
    local cancel = vim.fn.maparg("<C-q>", "n", false, true).callback
    -- Esc returns to normal mode; repeating it must not discard the draft.
    -- Enter, q, motions, operators, visual selections and undo stay native.
    vim.keymap.del("n", "<Esc>", { buffer = buf })
    vim.keymap.del("n", "<CR>", { buffer = buf })
    vim.keymap.set("n", "ZZ", submit, { buffer = buf, desc = "Save comment" })
    vim.keymap.set("n", "ZQ", cancel, { buffer = buf, desc = "Cancel comment" })
    vim.keymap.set("i", "<C-q>", cancel, { buffer = buf, desc = "Cancel comment" })
    vim.keymap.set("i", "<C-v>", "<C-r><C-p>+", { buffer = buf, desc = "Paste clipboard into comment" })
  end

  local comments = require("review.comments")
  comments.list = function()
    M.pick(notes.list(), require("config.review-navigation").jump)
  end
  notes.setup()
end

return M
