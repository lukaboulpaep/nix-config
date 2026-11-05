local M = {}
local ns = vim.api.nvim_create_namespace("desktop-review-selections")
local tracked = {}
local configured = false

-- History browsing deliberately includes notes from other comparisons. Cursor
-- actions and rendering use visible() instead, so they share eligibility.
function M.list(file)
  return vim.tbl_filter(function(note) return not file or note.file == file end,
    require("review.store").get_all())
end

function M.visible(file, side, buf)
  local session = require("codediff.ui.lifecycle").get_session(vim.api.nvim_get_current_tabpage())
  buf = buf or (session and (side == "old" and session.original_bufnr or session.modified_bufnr))
      or vim.api.nvim_get_current_buf()
  if session and buf ~= session.original_bufnr and buf ~= session.modified_bufnr then session = nil end
  local revision = session and (buf == session.original_bufnr and session.original_revision or session.modified_revision)
  return vim.tbl_filter(function(note)
    if side and note.line ~= 0 and (note.side or "new") ~= side then return false end
    if not note.revision then return true end
    -- Whole-file notes describe their comparison and appear above both panes.
    if note.line == 0 and session then
      return note.revision == (note.side == "old" and session.original_revision or session.modified_revision)
    end
    return note.revision == revision
  end, M.list(file))
end

local function persist()
  require("review.storage").save(require("review.store").get_all_by_file())
end

local function snapshot(buf)
  local session = require("codediff.ui.lifecycle").get_session(vim.api.nvim_get_current_tabpage())
  if not session or (buf ~= session.original_bufnr and buf ~= session.modified_bufnr) then return {} end
  local revision = buf == session.original_bufnr and session.original_revision or session.modified_revision
  local function commit(ref) return type(ref) == "string" and #ref >= 40 and ref:match("^%x+$") and ref or nil end
  local base, target = commit(session.original_revision), commit(session.modified_revision)
  return {
    revision = commit(revision),
    comparison = base and target and { base = base, target = target } or nil,
  }
end

function M.location(comment)
  if comment.line == 0 then return comment.file .. " (whole file)" end
  local location = comment.file .. ":" .. comment.line
  if comment.selection then
    location = location .. ":" .. (comment.selection.start_col + 1)
        .. "-" .. (comment.line_end or comment.line) .. ":" .. comment.selection.end_col
  elseif comment.line_end then
    location = location .. "-" .. comment.line_end
  end
  return location
end

---@param lines string[]
local function source_text(comment, lines)
  if comment.line == 0 then return table.concat(lines, "\n") end
  local first, last = comment.line, comment.line_end or comment.line
  if not lines[first] or not lines[last] then return nil end
  local selected = vim.list_slice(lines, first, last)
  if comment.selection then
    selected[#selected] = selected[#selected]:sub(1, comment.selection.end_col)
    selected[1] = selected[1]:sub(comment.selection.start_col + 1)
  end
  return table.concat(selected, "\n")
end

local function evidence(comment, buf, context)
  if not comment.source_hash then return { status = "" } end -- Legacy note.
  if comment.selection and comment.selection.invalid then return { status = "outdated", invalid = true } end
  local lines
  if buf and vim.api.nvim_buf_is_loaded(buf) then
    lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  else
    local session = context or require("codediff.ui.lifecycle").get_session(vim.api.nvim_get_current_tabpage())
    if comment.revision then
      local revision = session and (comment.side == "old" and session.original_revision or session.modified_revision)
      if revision ~= comment.revision then return { status = "historical" } end
    end
    local root = context and context.root or require("review.utils").git_root()
    if not root then return { status = "" } end
    local path = root .. "/" .. comment.file
    local loaded = vim.fn.bufnr(path)
    if loaded ~= -1 and vim.api.nvim_buf_is_loaded(loaded) and not comment.revision then
      lines = vim.api.nvim_buf_get_lines(loaded, 0, -1, false)
    elseif comment.revision then
      -- A committed snapshot is immutable; its saved SHA is its provenance.
      return { status = "" }
    elseif vim.fn.filereadable(path) == 1 then
      lines = vim.fn.readfile(path)
    else
      return { status = "outdated", missing = true }
    end
  end
  local text = source_text(comment, lines)
  local hash = text and vim.fn.sha256(text) or nil
  return { status = hash == comment.source_hash and "" or "outdated", hash = hash }
end

function M.status(comment, buf)
  return evidence(comment, buf).status
end

-- Capture note text and source evidence together, before an asynchronous picker
-- or draft opens. Rendering an export must never consult the live editor.
function M.capture(context)
  local comments, states = vim.deepcopy(M.list()), {}
  for i, note in ipairs(comments) do states[i] = evidence(note, nil, context) end
  return comments, states
end

local function refresh()
  vim.schedule(function()
    local marks = require("review.marks")
    marks.refresh()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) then marks.render_plain_buffer(buf) end
    end
  end)
end

function M.edit(note, done)
  local repository = require("config.review-repository")
  local root = repository.owner(note)
  require("review.popup").open(note.type, note.text, function(kind, text)
    if kind and text then
      repository.with_root(root, require("review.store").update, note.id, text, kind)
      refresh()
    end
    if done then done() end
  end)
end

function M.delete(note)
  local repository = require("config.review-repository")
  repository.with_root(repository.owner(note), require("review.store").delete, note.id)
  refresh()
end

function M.archive()
  require("review.storage").archive()
  require("review.store").reset()
  require("review.marks").clear_all()
  vim.notify("Comments archived; reviewed-file marks kept", vim.log.levels.INFO)
end

local function add(kind, first, last, selection)
  local repository = require("config.review-repository")
  local root = repository.root()
  local buf = vim.api.nvim_get_current_buf()
  local file, line, side = require("review.hooks").get_cursor_position()
  if not file then return end
  local metadata = snapshot(buf)
  first, last = first or line, last or first or line
  local source = source_text({ line = first, line_end = last, selection = selection },
    vim.api.nvim_buf_get_lines(buf, 0, -1, false))
  require("review.popup").open(kind or "note", nil, function(comment_type, text)
    if not comment_type or not text then return end
    repository.with_root(root, function()
      local note = require("review.store").add(file, first, comment_type, text, last, side)
      note.selection, note.revision, note.comparison = selection, metadata.revision, metadata.comparison
      note.source_hash = source and vim.fn.sha256(source) or nil
      persist()
    end)
    refresh()
  end)
end

function M.add_selection(kind, first, last)
  if first and last then
    return add(kind, math.min(first, last), math.max(first, last))
  end
  local mode = vim.fn.visualmode()
  if mode == "\22" then
    vim.notify("Use characterwise (v) or linewise (V) selection for a review note", vim.log.levels.INFO)
    return
  end
  local opts = { type = mode, exclusive = vim.o.selection == "exclusive", eol = true }
  local positions = vim.fn.getregionpos(vim.fn.getpos("'<"), vim.fn.getpos("'>"), opts)
  if #positions == 0 then return end
  local start, stop = positions[1][1], positions[#positions][2]
  local selection
  if mode == "v" then
    local line = vim.api.nvim_buf_get_lines(0, stop[2] - 1, stop[2], false)[1]
    local last_char = vim.fn.strcharpart(line:sub(stop[3]), 0, 1)
    selection = {
      start_col = math.max(0, start[3] - 1),
      end_col = math.min(#line, stop[3] - 1 + #last_char),
      text = table.concat(vim.fn.getregion(vim.fn.getpos("'<"), vim.fn.getpos("'>"), opts), "\n"),
    }
  end
  add(kind, start[2], stop[2], selection)
end

function M.at_cursor(callback, file_only)
  local file, line, side = require("review.hooks").get_cursor_position()
  if not file then return end
  local col, candidates, file_notes = vim.api.nvim_win_get_cursor(0)[2], {}, {}
  for _, note in ipairs(M.visible(file, side, vim.api.nvim_get_current_buf())) do
    if note.file == file then
      if note.line == 0 then
        table.insert(file_notes, note)
      elseif not file_only and (note.side or "new") == side
          and line >= note.line and line <= (note.line_end or note.line) then
        local selection = note.selection
        if not selection or ((line > note.line or col >= selection.start_col)
              and (line < (note.line_end or note.line) or col < selection.end_col)) then
          table.insert(candidates, note)
        end
      end
    end
  end
  if file_only or (#candidates == 0 and line == 1) then candidates = file_notes end
  if #candidates == 1 then
    callback(candidates[1])
  elseif #candidates > 1 then
    require("config.review-comments").pick(candidates, callback)
  else
    return false
  end
  return true
end

local function sync(buf)
  require("config.review-repository").ensure()
  local changed = false
  for id, mark in pairs(tracked[buf] or {}) do
    local note = require("review.store").get(id)
    local pos = vim.api.nvim_buf_get_extmark_by_id(buf, ns, mark, { details = true })
    local details = pos[3]
    if note and not note.revision and note.selection and details then
      if details.invalid then
        if not note.selection.invalid then note.selection.invalid, changed = true, true end
      elseif details.end_row and details.end_col then
        local last = details.end_row ~= pos[1] and (details.end_row + 1) or nil
        if note.line ~= pos[1] + 1 or note.line_end ~= last or note.selection.start_col ~= pos[2]
            or note.selection.end_col ~= details.end_col then
          note.line, note.line_end = pos[1] + 1, last
          note.selection.start_col, note.selection.end_col = pos[2], details.end_col
          changed = true
        end
      end
    end
  end
  if changed then persist() end
end

function M.setup()
  if configured then return end
  configured = true
  local comments, marks, store = require("review.comments"), require("review.marks"), require("review.store")
  local rendering_buf
  store.get_for_file = function(file, side)
    return M.visible(file, side, rendering_buf)
  end
  comments.add_at_cursor = function(kind) add(kind) end
  comments.add_for_range = M.add_selection
  comments.file_comment = function(kind)
    if not M.at_cursor(M.edit, true) then add(kind, 0, 0) end
  end
  comments.edit_at_cursor = function()
    if not M.at_cursor(M.edit) then vim.notify("No comment at cursor position", vim.log.levels.INFO) end
  end
  comments.delete_at_cursor = function()
    if not M.at_cursor(M.delete) then
      vim.notify("No comment at cursor position", vim.log.levels.INFO)
    end
  end
  local render = marks.render_for_buffer
  marks.render_for_buffer = function(buf, side, file)
    if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
    sync(buf)
    rendering_buf = buf
    local ok, err = xpcall(function() render(buf, side, file) end, debug.traceback)
    rendering_buf = nil
    if not ok then error(err) end
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    tracked[buf] = {}
    file = file or require("review.hooks").plain_buffer_file(buf)
    if not file then return end
    rendering_buf = buf
    local visible = store.get_for_file(file, side)
    rendering_buf = nil
    for _, note in ipairs(visible) do
      local selection = note.selection
      if selection and not selection.invalid then
        local ok, id = pcall(vim.api.nvim_buf_set_extmark, buf, ns, note.line - 1, selection.start_col, {
          end_row = (note.line_end or note.line) - 1,
          end_col = selection.end_col,
          hl_group = "Visual",
          right_gravity = true,
          end_right_gravity = false,
          invalidate = true,
        })
        if ok then tracked[buf][note.id] = id end
      end
      local status_buf = buf
      if note.line == 0 then
        local session = require("codediff.ui.lifecycle").get_session(vim.api.nvim_get_current_tabpage())
        status_buf = session and (note.side == "old" and session.original_bufnr or session.modified_bufnr) or buf
      end
      if M.status(note, status_buf) == "outdated" then
        pcall(vim.api.nvim_buf_set_extmark, buf, ns, math.max(0, note.line - 1), 0, {
          virt_text = { { " [outdated note]", "DiagnosticWarn" } }, virt_text_pos = "eol",
        })
      end
    end
  end
  local sync_positions = marks.sync_positions
  marks.sync_positions = function(buf)
    require("config.review-repository").ensure()
    local moved = sync_positions(buf)
    sync(buf)
    return moved
  end
  local clear = marks.clear_all
  marks.clear_all = function()
    clear()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1) end
    tracked = {}
  end
  vim.api.nvim_create_autocmd({ "TextChanged", "BufWritePost" }, {
    group = vim.api.nvim_create_augroup("DesktopReviewAnchors", { clear = true }),
    callback = function(event)
      if vim.bo[event.buf].buftype ~= "" then return end
      local file = require("review.hooks").plain_buffer_file(event.buf)
      if file and #M.visible(file, "new", event.buf) > 0 then
        -- Sync before redrawing, or rebuilding marks would discard the
        -- positions that Neovim already moved with the edit.
        marks.sync_positions(event.buf)
        refresh()
      end
    end,
  })
end

return M
