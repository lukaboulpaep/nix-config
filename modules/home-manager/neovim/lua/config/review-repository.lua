local M = {}
local forced_root
local owners = setmetatable({}, { __mode = "k" })
local git_root = require("review.utils").git_root

function M.root()
  if forced_root ~= nil then return forced_root or nil end
  local session = require("codediff.ui.lifecycle").get_session(vim.api.nvim_get_current_tabpage())
  local root = session and session.git_root or git_root()
  return root and (vim.uv.fs_realpath(root) or root)
end

function M.owner(note)
  return owners[note] or M.root()
end

-- A popup may outlive a directory/tab change. Keep its action in the repo
-- where it began, even when another repo contains the same comment ID.
function M.with_root(root, action, ...)
  local previous = forced_root
  forced_root = root or false
  local function pack(...) return { n = select("#", ...), ... } end
  local result = pack(pcall(action, ...))
  forced_root = previous
  if not result[1] then error(result[2]) end
  return unpack(result, 2, result.n)
end

function M.setup()
  if M.configured then return end
  M.configured = true
  local storage, store = require("review.storage"), require("review.store")
  local data_dir = vim.fn.stdpath("data") .. "/review"
  local function hash(root)
    -- Preserve review.nvim's existing filenames; no note migration required.
    local value = 0
    for i = 1, #root do value = (value * 31 + root:byte(i)) % 2147483647 end
    return string.format("%x", value)
  end
  storage.get_storage_path = function()
    local root = M.root()
    return root and (data_dir .. "/" .. hash(root) .. ".json")
  end
  storage.reviewed_path = function()
    local root = M.root()
    return root and (data_dir .. "/" .. hash(root) .. ".reviewed.json")
  end
  storage.git_branch = function()
    local root = M.root()
    if not root then return end
    local result = vim.fn.systemlist({ "git", "-C", root, "rev-parse", "--abbrev-ref", "HEAD" })
    return vim.v.shell_error == 0 and result[1] or nil
  end
  storage.legacy_storage_path = function()
    local root, branch = M.root(), storage.git_branch()
    return root and branch and (data_dir .. "/" .. hash(root) .. "-" .. branch:gsub("[^%w%-_]", "_") .. ".json") or nil
  end
  require("review.utils").git_root = function(dir)
    if dir then return git_root(dir) end
    return M.root()
  end

  local reset, load = store.reset, store.load
  local initialized, active_root = false, nil
  local function ensure()
    local root = M.root()
    if initialized and root == active_root then return end
    -- Remove anchors before switching: IDs and relative paths can coincide.
    require("review.marks").clear_all()
    reset()
    load()
    active_root, initialized = root, true
    for _, comments in pairs(store.comments) do
      for _, note in ipairs(comments) do owners[note] = root end
    end
  end
  M.ensure = ensure
  store.reset = function()
    reset()
    initialized = false
  end
  for _, name in ipairs({
    "load", "add", "get", "get_for_file", "get_file_comment", "get_at_line", "get_overlapping",
    "update", "move", "delete", "get_all", "get_all_by_file", "count", "count_from_other_branches",
    "archive_and_clear", "clear",
  }) do
    local original = store[name]
    store[name] = function(...)
      ensure()
      local result = original(...)
      if name == "add" and result then owners[result] = active_root end
      return result
    end
  end
end

return M
