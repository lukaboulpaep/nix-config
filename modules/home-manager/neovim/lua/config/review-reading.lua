local M = {}

function M.wrap_window(win)
  if not win or not vim.api.nvim_win_is_valid(win) then return end
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  vim.wo[win].breakindent = false
  vim.wo[win].scrollbind = false
  vim.wo[win].cursorbind = false
end

-- Virtual lines do not obey 'wrap'. Split by display cells, including Unicode
-- and tabs, and prefer word boundaries without changing the stored comment.
function M.wrap_text(text, width)
  local lines = {}
  for _, line in ipairs(vim.split(text, "\n", { plain = true })) do
    while vim.fn.strdisplaywidth(line) > width do
      local fit, boundary = 0, nil
      for i = 1, vim.fn.strchars(line) do
        local prefix = vim.fn.strcharpart(line, 0, i)
        if vim.fn.strdisplaywidth(prefix) > width then break end
        fit = #prefix
        if prefix:match("%s$") then boundary = fit end
      end
      -- A single wide glyph still needs to make progress in a tiny pane.
      local cut = boundary or (fit > 0 and fit or #vim.fn.strcharpart(line, 0, 1))
      lines[#lines + 1] = line:sub(1, cut)
      line = line:sub(cut + 1)
    end
    lines[#lines + 1] = line
  end
  return lines
end

local function comment_width(buf)
  local lifecycle = require("codediff.ui.lifecycle")
  local old, new = lifecycle.get_buffers(vim.api.nvim_get_current_tabpage())
  local width
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local shown = vim.api.nvim_win_get_buf(win)
    if shown == buf or ((buf == old or buf == new) and (shown == old or shown == new)) then
      local info = vim.fn.getwininfo(win)[1]
      local available = vim.api.nvim_win_get_width(win) - info.textoff - 4
      width = math.min(width or available, available)
    end
  end
  return math.max(1, width or 76)
end

-- review.nvim gives every box a minimum inner width of 20 cells. Shrink that
-- padding too when a resized pane is narrower, retaining the tracked mark IDs.
local function shrink_boxes(buf, width)
  if width >= 20 or not buf or not vim.api.nvim_buf_is_valid(buf) then return end
  local ns = vim.api.nvim_create_namespace("review")
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })) do
    local details = mark[4]
    if details.virt_lines then
      local lines = details.virt_lines
      for i, chunks in ipairs(lines) do
        local text, hl = chunks[1][1], chunks[1][2]
        if i == 1 then
          local label = text:match("%[.-%]") or ""
          label = vim.fn.strcharpart(label, 0, width + 2)
          chunks[1] = { "╭" .. label .. string.rep("─", width + 2 - vim.fn.strdisplaywidth(label)) .. "╮", hl }
        elseif i == #lines then
          chunks[1] = { "╰" .. string.rep("─", width + 2) .. "╯", hl }
        else
          text = text:sub(5, -5):gsub(" +$", "")
          chunks[1] = { "│ " .. text .. string.rep(" ", math.max(0, width - vim.fn.strdisplaywidth(text))) .. " │", hl }
        end
      end
      vim.api.nvim_buf_set_extmark(buf, ns, mark[2], mark[3], {
        id = mark[1],
        virt_lines = lines,
        virt_lines_above = details.virt_lines_above,
        sign_text = details.sign_text,
        sign_hl_group = details.sign_hl_group,
        line_hl_group = details.line_hl_group,
        right_gravity = details.right_gravity,
      })
    end
  end
end

function M.open_diff()
  local session = require("codediff.ui.lifecycle").get_session(vim.api.nvim_get_current_tabpage())
  if not session then
    vim.notify("Open a review first", vim.log.levels.INFO)
    return
  end
  local function content(buf)
    if not buf or not vim.api.nvim_buf_is_valid(buf) then return "" end
    return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n") .. "\n"
  end
  local patch = vim.text.diff(content(session.original_bufnr), content(session.modified_bufnr),
    { result_type = "unified", ctxlen = 3 })
  if patch == "" then
    vim.notify("No changes in this file", vim.log.levels.INFO)
    return
  end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(patch, "\n", { plain = true }))
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].modifiable = false
  local width, height = math.max(1, vim.o.columns - 6), math.max(1, vim.o.lines - 6)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    border = "rounded",
    style = "minimal",
    width = width,
    height = height,
    row = 1,
    col = 2,
    title = " Wrapped diff · q: return ",
    title_pos = "center",
  })
  vim.bo[buf].filetype = "diff"
  M.wrap_window(win)
  for _, key in ipairs({ "q", "<Esc>", "<leader>rw" }) do
    vim.keymap.set("n", key, function() vim.api.nvim_win_close(win, true) end, { buffer = buf, nowait = true })
  end
  vim.keymap.set("n", "j", "gj", { buffer = buf })
  vim.keymap.set("n", "k", "gk", { buffer = buf })
end

function M.setup()
  if M.configured then return end
  M.configured = true
  local store, marks = require("review.store"), require("review.marks")
  local get = store.get_for_file
  local width
  store.get_for_file = function(...)
    local comments = get(...)
    if not width then return comments end
    comments = vim.deepcopy(comments)
    for _, comment in ipairs(comments) do
      comment.text = table.concat(M.wrap_text(comment.text, width), "\n")
    end
    return comments
  end
  -- Use the same width while rendering boxes and calculating opposite-pane
  -- padding, so wrapped comments do not knock the code out of alignment.
  for _, name in ipairs({ "render_for_buffer", "align_buffers" }) do
    local original = marks[name]
    marks[name] = function(buf, ...)
      local previous = width
      local available = comment_width(buf)
      width = available
      local ok, err = pcall(original, buf, ...)
      width = previous
      if not ok then error(err) end
      if name == "render_for_buffer" then shrink_boxes(buf, available) end
    end
  end
  vim.api.nvim_create_autocmd("WinResized", {
    group = vim.api.nvim_create_augroup("DesktopReviewReading", { clear = true }),
    callback = function()
      vim.schedule(function()
        marks.refresh()
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          marks.render_plain_buffer(vim.api.nvim_win_get_buf(win))
        end
      end)
    end,
  })
  vim.keymap.set("n", "<leader>rw", M.open_diff, { desc = "Read diff with wrapped lines" })
end

return M
