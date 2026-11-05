local M = {}
local lifecycle = require("codediff.ui.lifecycle")
local last_review_tab
local last_editor_win
local pending
local configured = false

local function editor_window(win)
  return win and vim.api.nvim_win_is_valid(win)
      and not lifecycle.get_session(vim.api.nvim_win_get_tabpage(win))
      and vim.api.nvim_win_get_config(win).relative == ""
      and vim.bo[vim.api.nvim_win_get_buf(win)].buftype == ""
end

local function place_cursor(win, cursor)
  local buf = vim.api.nvim_win_get_buf(win)
  local line = math.min(math.max(1, cursor[1]), vim.api.nvim_buf_line_count(buf))
  local text = vim.api.nvim_buf_get_lines(buf, line - 1, line, false)[1] or ""
  vim.api.nvim_win_set_cursor(win, { line, math.min(cursor[2], #text) })
end

local function open_working(path, cursor)
  if not path or path == "" then
    vim.notify("Select a file or focus a diff pane first", vim.log.levels.INFO)
    return
  end
  local existing = vim.fn.bufnr(path)
  if vim.fn.filereadable(path) ~= 1 and not (existing > 0 and vim.api.nvim_buf_is_loaded(existing)) then
    vim.notify("File is absent from the current checkout: " .. path, vim.log.levels.WARN)
    return
  end

  local target = editor_window(last_editor_win) and last_editor_win or nil
  -- Prefer an existing view of this file, even after exploring other tabs.
  for _, win in ipairs(existing > 0 and vim.fn.win_findbuf(existing) or {}) do
    if editor_window(win) then
      target = win
      break
    end
  end
  if not target then
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if editor_window(win) then
        target = win
        break
      end
    end
  end
  if target then
    vim.api.nvim_set_current_win(target)
  else
    vim.cmd.tabnew()
  end
  last_editor_win = vim.api.nvim_get_current_win()
  -- :edit reloads an already open file and can reject unsaved edits. Reuse its
  -- buffer; :hide also preserves edits in the editor's previous file.
  local file = existing > 0 and existing or vim.fn.bufadd(path)
  vim.cmd("hide buffer " .. file)
  vim.bo[file].buflisted = true
  if cursor then
    place_cursor(0, cursor)
  end
end

function M.open()
  local tab = vim.api.nvim_get_current_tabpage()
  local session = lifecycle.get_session(tab)
  if not session then
    vim.notify("Open a review before choosing a file to explore", vim.log.levels.INFO)
    return
  end
  local buf = vim.api.nvim_get_current_buf()
  local path, cursor
  if buf == session.original_bufnr or buf == session.modified_bufnr then
    local original, modified = lifecycle.get_paths(tab)
    local ref = buf == session.original_bufnr and original or modified
    path = ref and ref.absolute
    cursor = vim.api.nvim_win_get_cursor(0)
  else
    local explorer = require("review.hooks").get_explorer(tab)
    local node = explorer and explorer.bufnr == buf and explorer.tree:get_node()
    local data = node and node.data
    if data and not data.type and data.path then
      path = vim.fs.joinpath(data.git_root or explorer.git_root or session.git_root, data.path)
    end
  end
  last_review_tab = tab
  open_working(path, cursor)
end

function M.jump(note)
  M.setup()
  pending = nil -- A newer request supersedes any delayed jump.
  local origin = vim.api.nvim_get_current_tabpage()
  local session = lifecycle.get_session(origin)
  local root = (session and session.git_root) or require("review.utils").git_root()
  local cursor = { note.line, note.selection and note.selection.start_col or 0 }
  if not session and not note.comparison then
    if root then open_working(vim.fs.joinpath(root, note.file), cursor) end
    return
  end
  local function matches(active)
    return active and active.git_root == root and (not note.comparison
      or (active.original_revision == note.comparison.base and active.modified_revision == note.comparison.target))
  end
  local opening = note.comparison and not matches(session)
  local request = { origin = origin, tab = not opening and origin or nil, existing = {} }
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do request.existing[tab] = true end
  pending = request
  if opening then
    require("review").open_commits(note.comparison.base, note.comparison.target)
  end
  local attempts, selected_path = 0, nil
  local function navigate()
    if pending ~= request then return end
    attempts = attempts + 1
    local tab = request.tab
    if tab and (not vim.api.nvim_tabpage_is_valid(tab) or vim.api.nvim_get_current_tabpage() ~= tab) then
      pending = nil
      return
    end
    local active = tab and lifecycle.get_session(tab)
    local explorer = tab and require("review.hooks").get_explorer(tab)
    if matches(active) and explorer then
      if not selected_path then
        for _, group in ipairs({ "unstaged", "staged", "conflicts" }) do
          for _, file in ipairs((explorer.data.status_result or {})[group] or {}) do
            if file.path == note.file or file.old_path == note.file then
              selected_path = note.side == "old" and (file.old_path or file.path) or file.path
              explorer.on_file_select(vim.tbl_extend("force", file, { group = group }))
              break
            end
          end
          if selected_path then break end
        end
      end
      local old, new = lifecycle.get_buffers(tab)
      local buf = note.side == "old" and old or new
      local old_win, new_win = lifecycle.get_windows(tab)
      local win = note.side == "old" and old_win or new_win
      local revision = note.side == "old" and active.original_revision or active.modified_revision
      if selected_path and buf and vim.api.nvim_buf_is_valid(buf) and win and vim.api.nvim_win_is_valid(win)
          and vim.api.nvim_win_get_buf(win) == buf
          and vim.endswith(vim.api.nvim_buf_get_name(buf), "/" .. selected_path)
          and (not note.revision or revision == note.revision) then
        pending = nil
        vim.api.nvim_set_current_win(win)
        place_cursor(win, cursor)
        return
      end
    end
    if attempts < 50 then
      vim.defer_fn(navigate, 100)
    else
      pending = nil
      vim.notify("Could not locate the comment in this review", vim.log.levels.WARN)
    end
  end
  vim.defer_fn(navigate, 150)
end

function M.back()
  if last_review_tab and vim.api.nvim_tabpage_is_valid(last_review_tab)
      and lifecycle.get_session(last_review_tab) then
    vim.api.nvim_set_current_tabpage(last_review_tab)
  else
    vim.notify("No open review to return to", vim.log.levels.INFO)
  end
end

function M.setup()
  if configured then return end
  configured = true
  local group = vim.api.nvim_create_augroup("DesktopReviewNavigation", { clear = true })
  vim.api.nvim_create_autocmd("TabLeave", {
    group = group,
    callback = function()
      local tab = vim.api.nvim_get_current_tabpage()
      local win = vim.api.nvim_get_current_win()
      if pending and pending.tab == tab then pending = nil end
      if lifecycle.get_session(tab) then
        last_review_tab = tab
      elseif editor_window(win) then
        last_editor_win = win
      end
    end,
  })
  vim.api.nvim_create_autocmd("TabEnter", {
    group = group,
    callback = function()
      if not pending then return end
      local tab = vim.api.nvim_get_current_tabpage()
      -- CodeDiff creates its tab asynchronously. Bind once to that new tab;
      -- switching to an existing tab means the user has abandoned this jump.
      if not pending.tab and not pending.existing[tab] then
        pending.tab = tab
      elseif tab ~= pending.tab then
        pending = nil
      end
    end,
  })
  vim.keymap.set("n", "<leader>ro", M.open, { desc = "Open reviewed file in working tree" })
  vim.keymap.set("n", "<leader>rO", M.back, { desc = "Return to review" })
end

return M
