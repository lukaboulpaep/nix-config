-- nvim --headless -u NONE -i NONE -n -l /path/to/tests/review-repository.lua
-- Real plugin storage, isolated repositories and data; no personal notes used.
local config = vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)))
vim.opt.runtimepath:prepend(config)
for _, path in ipairs(vim.fn.glob(vim.fn.stdpath("data") .. "/site/pack/core/opt/*", false, true)) do
  vim.opt.runtimepath:append(path)
end
local scratch = vim.fn.tempname()
vim.fn.mkdir(scratch, "p")
vim.env.XDG_DATA_HOME = scratch .. "/data"
vim.env.XDG_STATE_HOME = scratch .. "/state"
vim.env.XDG_CACHE_HOME = scratch .. "/cache"
vim.env.NVIM_LOG_FILE = scratch .. "/nvim.log"
vim.o.swapfile = false
vim.o.hidden = true
local a, b = scratch .. "/repo-a", scratch .. "/repo-b"
for _, root in ipairs({ a, b }) do
  vim.fn.mkdir(root, "p")
  vim.fn.system({ "git", "init", "-q", root })
  assert(vim.v.shell_error == 0)
  vim.fn.writefile({ "first", "second", "third" }, root .. "/same.lua")
end
local function cd(path) vim.cmd.cd(vim.fn.fnameescape(path)) end
local function run()
  local storage = require("review.storage")
  local id = "comment_100_1"
  local function seed(root, text)
    cd(root)
    local path = storage.get_storage_path()
    storage.save({ ["same.lua"] = { { id = id, file = "same.lua", line = 2, side = "new",
      type = "note", text = text, created_at = 100 } } })
    return path
  end
  local path_a, path_b = seed(a, "Only A"), seed(b, "Only B")
  require("config.review")
  local repository = require("config.review-repository")
  local notes, store = require("config.review-notes"), require("review.store")
  cd(a)
  assert(storage.get_storage_path() == path_a, "Existing storage filename changed")
  local note_a = notes.list()[1]
  assert(note_a.text == "Only A")
  cd(b)
  assert(storage.get_storage_path() == path_b)
  assert(#notes.list() == 1 and notes.list()[1].text == "Only B")
  cd(scratch)
  assert(#notes.list() == 0, "Notes leaked outside a repository")
  cd(a)
  assert(notes.list("same.lua")[1].text == "Only A", "Returning to a repo lost its notes")
  assert(require("review.utils").git_root(scratch) == nil, "Explicit non-repo lookup used the active repo")

  -- Anchors from A must not move a same-ID note in B after changing cwd.
  local marks = require("review.marks")
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_name(buf, a .. "/same.lua")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "first", "second", "third" })
  marks.render_for_buffer(buf, "new", "same.lua")
  vim.api.nvim_buf_set_lines(buf, 0, 0, false, { "inserted" })
  cd(b)
  marks.sync_positions(buf)
  assert(notes.list()[1].line == 2, "An old buffer anchor moved another repo's note")
  vim.api.nvim_buf_delete(buf, { force = true })
  cd(a)

  -- Editing A in a popup while switching to B must not overwrite B's same ID.
  local popup = require("review.popup")
  local original_open, callback = popup.open
  popup.open = function(_, _, done) callback = done end
  notes.edit(note_a)
  cd(b)
  assert(notes.list()[1].text == "Only B")
  callback("issue", "Edited A")
  popup.open = original_open
  assert(notes.list()[1].text == "Only B", "Popup saved into the wrong repository")
  cd(a)
  assert(notes.list()[1].text == "Edited A")
  assert(notes.list()[1].type == "issue")

  -- A CodeDiff tab keeps its repository even when the global cwd changes.
  local lifecycle = require("codediff.ui.lifecycle")
  local original_session = lifecycle.get_session
  lifecycle.get_session = function() return { git_root = a } end
  cd(b)
  assert(repository.root() == a and notes.list()[1].text == "Edited A")
  assert(storage.get_storage_path() == path_a)
  lifecycle.get_session = original_session
  assert(notes.list()[1].text == "Only B")

  notes.delete(note_a)
  assert(notes.list()[1].text == "Only B", "Deleting an old picker item deleted B's note")
  assert(#repository.with_root(a, notes.list) == 0)
  assert(notes.list()[1].text == "Only B")
  local created = store.add("new.lua", 1, "note", "New B")
  assert(repository.owner(created) == b)
  store.update(created.id, "Updated B")
  store.reset()
  assert(#notes.list() == 2, "Repository writes did not survive reload")
  local text = require("review.export").generate_markdown()
  assert(text:find("Only B", 1, true) and text:find("Updated B", 1, true))
  assert(not text:find("Only A", 1, true) and not text:find("Edited A", 1, true))
  local saved_a = vim.json.decode(table.concat(vim.fn.readfile(path_a), "\n"))
  assert(vim.tbl_isempty(saved_a), "Deleting A did not update A's file")
  print("PASS repository switching, saved-note compatibility, popup ownership, review-tab scope, deletion and export isolation")
end
local ok, err = xpcall(run, debug.traceback)
if not ok then print(err) end
-- Finish scheduled mark refreshes while the temporary repositories still exist.
vim.wait(50, function() return false end, 10)
cd("/tmp")
vim.fn.delete(scratch, "rf")
vim.cmd(ok and "qa!" or "cquit 1")
