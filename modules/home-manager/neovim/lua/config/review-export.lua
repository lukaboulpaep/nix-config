local M = {}
local templates = require("config.review-templates")
local notes = require("config.review-notes")
local saved = {}

local function substitute(text, values)
  return (text:gsub("{([%w_]+)}", function(key) return values[key] or ("{" .. key .. "}") end))
end

local function code(text)
  local width = 1
  for ticks in text:gmatch("`+") do width = math.max(width, #ticks + 1) end
  local fence = string.rep("`", width)
  local padding = text:match("^`") or text:match("`$")
  return fence .. (padding and " " or "") .. text .. (padding and " " or "") .. fence
end

local function choice(entries, id)
  for _, entry in ipairs(entries) do
    if entry.id == id then return entry end
  end
  error("Unknown review template: " .. tostring(id))
end

local function context()
  local lifecycle = require("codediff.ui.lifecycle")
  local tab = vim.api.nvim_get_current_tabpage()
  local session, panel = lifecycle.get_session(tab), lifecycle.get_panel(tab)
  local data = panel and panel.data or {}
  local base = data.base_revision
  local target = data.target_revision
  if (not panel or panel.name ~= "explorer") and session then
    base, target = session.original_revision, session.modified_revision
  end
  return {
    root = (session and session.git_root) or require("review.utils").git_root() or vim.fn.getcwd(),
    base = base,
    target = target,
    original_revision = session and session.original_revision,
    modified_revision = session and session.modified_revision,
    text = base and ("Reviewed comparison: " .. code(base) .. " → " .. code(target or "WORKING"))
        or "Review of working changes.",
  }
end

local function capture()
  local current = context()
  local comments, states = notes.capture(current)
  return { comments = comments, context = current, states = states }
end

local function render(audience, action, snapshot)
  local blocks = {}
  for i, comment in ipairs(snapshot.comments) do
    local location = notes.location(comment)
    local revision = comment.revision and ("\n\nSnapshot: " .. code(comment.revision)) or ""
    if comment.comparison then
      revision = revision .. "\n\nReviewed range: " .. code(comment.comparison.base)
          .. " → " .. code(comment.comparison.target)
    end
    local status = snapshot.states[i].status
    if status ~= "" then revision = revision ..
      "\n\nStatus: " .. status .. " (needs verification, not automatically resolved)." end
    local selection = ""
    if comment.selection then
      selection = "\n\nSelected code:\n\n> " .. comment.selection.text:gsub("\n", "\n> ")
    end
    blocks[i] = substitute(templates.comment, {
      index = tostring(i),
      type = comment.type:upper(),
      location = code(location),
      file = comment.file,
      side = comment.side or "new",
      text = comment.text,
      revision = revision,
      selection = selection,
    })
  end
  local audience_template = choice(templates.audiences, audience)
  return substitute(templates.document, {
    audience = audience_template.text,
    action = (audience_template.actions or {})[action] or choice(templates.actions, action).text,
    context = snapshot.context.text,
    comments = table.concat(blocks, "\n\n"),
    count = tostring(#snapshot.comments),
  })
end

local function matches(draft, snapshot)
  return draft and vim.deep_equal(draft.snapshot, snapshot)
end

local function generate(snapshot)
  local draft = saved[snapshot.context.root]
  if matches(draft, snapshot) then return draft.text end
  local same_context = draft and vim.deep_equal(draft.snapshot.context, snapshot.context)
  return render(same_context and draft.audience or templates.default_audience,
    same_context and draft.action or templates.default_action, snapshot)
end

local function deliver(text, snapshot)
  local cfg = require("review.config").get().export
  if cfg.clipboard ~= false then
    vim.fn.setreg("+", text)
    vim.fn.setreg("*", text)
  end
  if type(cfg.on_export) == "function" then
    local ok, err = pcall(cfg.on_export, text, vim.deepcopy(snapshot.comments))
    if not ok then vim.notify(tostring(err), vim.log.levels.ERROR) end
  end
end

local function edit(audience, action, snapshot)
  local draft = saved[snapshot.context.root]
  local markdown = matches(draft, snapshot) and draft.audience == audience and draft.action == action
      and draft.text or render(audience, action, snapshot)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(markdown, "\n", { plain = true }))
  vim.bo[buf].bufhidden = "wipe"
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    border = "rounded",
    style = "minimal",
    width = math.max(1, math.min(110, vim.o.columns - 6)),
    height = math.max(1, math.min(30, vim.o.lines - 6)),
    row = 2,
    col = math.max(0, math.floor((vim.o.columns - math.min(110, vim.o.columns - 6)) / 2)),
    title = " Captured review · Ctrl-s / ZZ: copy · ZQ: cancel ",
    title_pos = "center",
  })
  vim.bo[buf].filetype = "markdown"
  require("config.review-reading").wrap_window(win)
  vim.cmd.stopinsert()
  local function close()
    vim.cmd.stopinsert()
    vim.api.nvim_win_close(win, true)
  end
  local function copy()
    local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    deliver(text, snapshot)
    -- A draft remains a snapshot even if its source changes while it is open.
    -- Save the evidence used to render it, never newer evidence read at copy.
    saved[snapshot.context.root] = {
      audience = audience,
      action = action,
      text = text,
      snapshot = snapshot
    }
    close()
    vim.notify(require("review.export").delivered_message(#snapshot.comments), vim.log.levels.INFO)
  end
  vim.keymap.set({ "n", "i" }, "<C-s>", copy, { buffer = buf, desc = "Copy edited review export" })
  vim.keymap.set("n", "ZZ", copy, { buffer = buf, desc = "Copy edited review export" })
  vim.keymap.set("n", "ZQ", close, { buffer = buf, desc = "Cancel review export" })
  vim.keymap.set({ "n", "i" }, "<C-q>", close, { buffer = buf, desc = "Cancel review export" })
end

local function pick(title, entries, preview, selected)
  local actions, state = require("telescope.actions"), require("telescope.actions.state")
  require("telescope.pickers").new({}, {
    prompt_title = title,
    layout_strategy = "vertical",
    layout_config = { width = 0.9, height = 0.9, preview_height = 0.6, preview_cutoff = 1 },
    finder = require("telescope.finders").new_table({
      results = entries,
      entry_maker = function(entry)
        return { value = entry, display = entry.label, ordinal = entry.label }
      end
    }),
    sorter = require("telescope.config").values.generic_sorter({}),
    previewer = require("telescope.previewers").new_buffer_previewer({
      title = "Markdown preview",
      define_preview = function(self, entry)
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false,
          vim.split(preview(entry.value), "\n", { plain = true }))
        require("telescope.previewers.utils").highlighter(self.state.bufnr, "markdown")
        require("config.review-reading").wrap_window(self.state.winid)
      end,
    }),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local entry = state.get_selected_entry()
        actions.close(prompt_bufnr)
        if entry then vim.schedule(function() selected(entry.value) end) end
      end)
      return true
    end,
  }):find()
end

function M.choose()
  local snapshot = capture()
  if #snapshot.comments == 0 then
    vim.notify("No comments to export", vim.log.levels.INFO)
    return
  end
  pick("Review audience", templates.audiences, function(audience)
    return render(audience.id, templates.default_action, snapshot)
  end, function(audience)
    pick("Requested action", templates.actions, function(action)
      return render(audience.id, action.id, snapshot)
    end, function(action) edit(audience.id, action.id, snapshot) end)
  end)
end

function M.setup()
  local export = require("review.export")
  export.generate_markdown = function() return generate(capture()) end
  export.deliver = function()
    local snapshot = capture()
    if #snapshot.comments == 0 then return nil, 0 end
    local text = generate(snapshot)
    deliver(text, snapshot)
    return text, #snapshot.comments
  end
  export.to_clipboard = M.choose
  export.preview = M.choose
end

return M
