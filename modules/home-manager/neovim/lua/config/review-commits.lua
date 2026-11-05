local M = {}

-- The upstream picker extends a range on Space. Keep explicit checkboxes so
-- pressing Space again really removes that commit from the selection.
function M.open(callback)
  local lines = vim.fn.systemlist({ "git", "log", "-50", "--format=%H%x09%h%x09%an%x09%cr%x09%s" })
  if vim.v.shell_error ~= 0 or #lines == 0 then
    vim.notify("No commits found in the current repository", vim.log.levels.WARN)
    return
  end
  local commits = {}
  for _, line in ipairs(lines) do
    local fields = vim.split(line, "\t", { plain = true })
    commits[#commits + 1] = {
      hash = fields[1],
      short = fields[2],
      label = table.concat(fields, "\t", 5),
      meta = "(" .. fields[3] .. ", " .. fields[4] .. ")",
    }
  end

  local selected, touched = {}, false
  local popup = require("nui.popup")({
    position = "50%",
    size = { width = math.min(120, vim.o.columns - 10), height = math.min(20, #commits, vim.o.lines - 10) },
    border = {
      style = "rounded",
      text = {
        top = " Select commits to review ",
        top_align = "center",
        bottom = " Space toggle | r reset | Enter review range | q cancel ",
        bottom_align = "center",
      }
    },
    buf_options = { modifiable = false, buftype = "nofile" },
    win_options = { cursorline = true, cursorlineopt = "line", wrap = false },
  })
  popup:mount()
  local ns = vim.api.nvim_create_namespace("desktop-review-commits")
  local function render()
    local cursor = vim.api.nvim_win_get_cursor(popup.winid)
    local rows = {}
    for i, commit in ipairs(commits) do
      rows[i] = (selected[i] and "[x] " or "[ ] ") .. commit.short .. " " .. commit.label .. " " .. commit.meta
    end
    vim.bo[popup.bufnr].modifiable = true
    vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, rows)
    vim.bo[popup.bufnr].modifiable = false
    vim.api.nvim_buf_clear_namespace(popup.bufnr, ns, 0, -1)
    for i, commit in ipairs(commits) do
      if selected[i] then
        vim.api.nvim_buf_set_extmark(popup.bufnr, ns, i - 1, 0,
          { end_col = 3, hl_group = "ReviewPickerSelected" })
      end
      vim.api.nvim_buf_set_extmark(popup.bufnr, ns, i - 1, 4,
        { end_col = 4 + #commit.short, hl_group = "ReviewPickerHash" })
      vim.api.nvim_buf_set_extmark(popup.bufnr, ns, i - 1, #rows[i] - #commit.meta,
        { end_col = #rows[i], hl_group = "ReviewPickerMeta" })
    end
    vim.api.nvim_win_set_cursor(popup.winid, cursor)
  end
  render()
  vim.api.nvim_set_current_win(popup.winid)
  local opts = { noremap = true, nowait = true }
  popup:map("n", "<Space>", function()
    local row = vim.api.nvim_win_get_cursor(popup.winid)[1]
    selected[row] = not selected[row] or nil
    touched = true
    render()
  end, opts)
  popup:map("n", "r", function()
    selected, touched = {}, true
    render()
  end, opts)
  popup:map("n", "<CR>", function()
    local first, last, count = nil, nil, 0
    for i = 1, #commits do
      if selected[i] then
        first, last, count = first or i, i, count + 1
      end
    end
    -- Preserve Enter-to-review on an untouched picker, but never reselect a
    -- commit after the user explicitly unchecked everything.
    if not first and not touched then
      first = vim.api.nvim_win_get_cursor(popup.winid)[1]
      last, count = first, 1
    end
    if not first or not last then
      vim.notify("Select at least one commit with Space", vim.log.levels.INFO)
      return
    end
    if count ~= last - first + 1 then
      vim.notify("Select a continuous range; unchecked commits would otherwise be included in the diff",
        vim.log.levels.WARN)
      return
    end
    popup:unmount()
    callback(commits[last].hash .. "^", commits[first].hash)
  end, opts)
  for _, key in ipairs({ "q", "<Esc>" }) do
    popup:map("n", key, function() popup:unmount() end, opts)
  end
end

function M.setup()
  require("review.picker").open = M.open
end

return M
