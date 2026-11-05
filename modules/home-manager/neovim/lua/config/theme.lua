local M = {}
local uv = vim.uv
local config_home = vim.env.XDG_CONFIG_HOME or (vim.env.HOME .. "/.config")
local state_home = vim.env.XDG_STATE_HOME or (vim.env.HOME .. "/.local/state")
local tokens_path = config_home .. "/desktop-theme/tokens.json"
local mode_path = state_home .. "/desktop-theme/mode"
local watchers = {}
local current

local function blend(foreground, background, amount)
  local channels = {}
  for i = 1, 5, 2 do
    local fg = tonumber(foreground:sub(i + 1, i + 2), 16)
    local bg = tonumber(background:sub(i + 1, i + 2), 16)
    channels[#channels + 1] = string.format("%02x", math.floor(fg * amount + bg * (1 - amount) + 0.5))
  end
  return "#" .. table.concat(channels)
end

local function read(path)
  local file = io.open(path, "r")
  if not file then return nil end
  local contents = file:read("*a")
  file:close()
  return contents
end

function M.apply()
  local contents = read(tokens_path)
  if not contents then return end
  local ok, tokens = pcall(vim.json.decode, contents)
  if not ok or type(tokens) ~= "table" or not tokens.palettes then return end
  local mode = vim.trim(read(mode_path) or tokens.defaultMode)
  if mode ~= "light" and mode ~= "dark" then mode = tokens.defaultMode end
  local palette = tokens.palettes[mode]
  if not palette or not palette.ansi then return end
  local signature = mode .. contents
  if signature == current then return end
  current = signature

  vim.o.background = mode
  vim.cmd("highlight clear")
  vim.g.colors_name = "desktop"
  local p, a = vim.deepcopy(palette), palette.ansi
  -- Match Ghostty's warm cream canvas; use the lighter surface for panels.
  if mode == "light" then p.background, p.frame = p.frame, p.background end
  local groups = {
    Normal = { fg = p.foreground, bg = p.background },
    NormalNC = { link = "Normal" },
    NormalFloat = { fg = p.foreground, bg = p.frame },
    FloatBorder = { fg = p.outline, bg = p.frame },
    FloatTitle = { fg = p.accent, bg = p.frame, bold = true },
    SignColumn = { fg = p.foreground, bg = p.background },
    LineNr = { fg = a[9] },
    CursorLineNr = { fg = p.accent, bold = true },
    CursorLine = { bg = p.frame },
    Cursor = { fg = p.background, bg = p.accent },
    Visual = { bg = p.selection },
    Search = { fg = p.background, bg = a[4] },
    IncSearch = { fg = p.background, bg = p.accent },
    MatchParen = { fg = p.accent, bg = p.selection, bold = true },
    WinSeparator = { fg = p.outline },
    StatusLine = { fg = p.foreground, bg = p.frame },
    StatusLineNC = { fg = a[9], bg = p.frame },
    TabLine = { fg = a[9], bg = p.frame },
    TabLineFill = { bg = p.frame },
    TabLineSel = { fg = p.accent, bg = p.background, bold = true },
    Pmenu = { fg = p.foreground, bg = p.frame },
    PmenuSel = { fg = p.foreground, bg = p.selection, bold = true },
    PmenuSbar = { bg = p.frame },
    PmenuThumb = { bg = p.outline },
    TelescopeNormal = { fg = p.foreground, bg = p.frame },
    TelescopeBorder = { fg = p.outline, bg = p.frame },
    TelescopeTitle = { fg = p.accent, bold = true },
    TelescopePromptPrefix = { fg = p.accent },
    TelescopeSelection = { fg = p.foreground, bg = p.selection },
    TelescopeMatching = { fg = a[5], bold = true },
    Folded = { fg = a[9], bg = p.frame },
    FoldColumn = { fg = a[9], bg = p.background },
    EndOfBuffer = { fg = p.outline },
    NonText = { fg = p.outline },
    Whitespace = { fg = p.outline },
    Title = { fg = p.accent, bold = true },
    Directory = { fg = a[5] },
    Comment = { fg = a[9], italic = true },
    Constant = { fg = a[4] },
    String = { fg = a[3] },
    Character = { link = "String" },
    Number = { fg = a[4] },
    Boolean = { fg = a[4], bold = true },
    Float = { link = "Number" },
    Identifier = { fg = p.foreground },
    Function = { fg = a[5] },
    Statement = { fg = a[6] },
    Keyword = { fg = a[6], italic = true },
    Operator = { fg = p.accent },
    PreProc = { fg = a[7] },
    Type = { fg = a[7] },
    Special = { fg = p.accent },
    Delimiter = { fg = a[9] },
    Underlined = { fg = a[5], underline = true },
    Todo = { fg = p.background, bg = a[4], bold = true },
    Error = { fg = a[2] },
    ErrorMsg = { fg = a[2] },
    WarningMsg = { fg = a[4] },
    DiffAdd = { bg = blend(a[3], p.background, 0.16) },
    DiffChange = { bg = blend(a[5], p.background, 0.12) },
    DiffDelete = { fg = a[2], bg = blend(a[2], p.background, 0.16) },
    DiffText = { bg = blend(a[5], p.background, 0.28), bold = true },
    DesktopDiffAddText = { bg = blend(a[3], p.background, 0.32) },
    DesktopDiffDeleteText = { bg = blend(a[2], p.background, 0.32) },
    CodeDiffLineMove = { bg = blend(a[5], p.background, 0.16) },
    CodeDiffCharMove = { bg = blend(a[5], p.background, 0.32) },
    CodeDiffMoveFrom = { fg = a[5] },
    CodeDiffMoveTo = { fg = a[5] },
    CodeDiffFiller = { fg = p.outline },
    ReviewNote = { fg = a[5] },
    ReviewSuggestion = { fg = a[3] },
    ReviewIssue = { fg = a[4] },
    ReviewPraise = { fg = a[6] },
    ReviewNoteLine = { bg = blend(a[5], p.background, 0.16) },
    ReviewSuggestionLine = { bg = blend(a[3], p.background, 0.16) },
    ReviewIssueLine = { bg = blend(a[4], p.background, 0.16) },
    ReviewPraiseLine = { bg = blend(a[6], p.background, 0.16) },
    GitSignsAdd = { fg = a[3] },
    GitSignsChange = { fg = a[5] },
    GitSignsDelete = { fg = a[2] },
    GitSignsCurrentLineBlame = { fg = a[9], italic = true },
    NeoTreeNormal = { fg = p.foreground, bg = p.frame },
    NeoTreeNormalNC = { link = "NeoTreeNormal" },
    NeoTreeEndOfBuffer = { fg = p.frame, bg = p.frame },
    NeoTreeDirectoryIcon = { fg = p.accent },
    NeoTreeDirectoryName = { fg = p.foreground },
    NeoTreeFileName = { fg = p.foreground },
    NeoTreeFileNameOpened = { fg = p.foreground, bold = true },
    NeoTreeDotfile = { fg = a[9] },
    NeoTreeDimText = { fg = a[9] },
    NeoTreeModified = { fg = a[4] },
    NeoTreeTabActive = { fg = p.accent, bg = p.frame, bold = true },
    NeoTreeTabInactive = { fg = a[9], bg = p.frame },
    NeoTreeTabSeparatorActive = { fg = p.outline, bg = p.frame },
    NeoTreeTabSeparatorInactive = { fg = p.outline, bg = p.frame },
    NeoTreeRootName = { fg = p.accent, bold = true },
    NeoTreeIndentMarker = { fg = p.outline },
    NeoTreeCursorLine = { bg = p.selection },
    NeoTreeGitAdded = { fg = a[3] },
    NeoTreeGitModified = { fg = a[4] },
    NeoTreeGitDeleted = { fg = a[2] },
    NeoTreeGitConflict = { fg = a[2], bold = true },
    NeoTreeGitUntracked = { fg = a[7] },
    NeoTreeGitIgnored = { fg = a[9] },
    LspReferenceText = { bg = p.selection },
    LspReferenceRead = { bg = p.selection },
    LspReferenceWrite = { bg = p.selection },
    LspInlayHint = { fg = a[9], bg = p.frame, italic = true },
    ["@variable"] = { fg = p.foreground },
    ["@variable.builtin"] = { fg = p.accent },
    ["@variable.parameter"] = { fg = p.foreground, italic = true },
    ["@property"] = { fg = a[7] },
    ["@markup.heading"] = { fg = p.accent, bold = true },
    ["@markup.link"] = { fg = a[5], underline = true },
  }
  for name, color in pairs({ Error = a[2], Warn = a[4], Info = a[5], Hint = a[7], Ok = a[3] }) do
    groups["Diagnostic" .. name] = { fg = color }
    groups["DiagnosticUnderline" .. name] = { sp = color, undercurl = true }
  end
  for name, spec in pairs(groups) do
    vim.api.nvim_set_hl(0, name, spec)
  end
  -- Keep file glyphs in the shared accent instead of plugin brand colors.
  local devicons = require("nvim-web-devicons")
  local icons = vim.deepcopy(devicons.get_icons())
  for _, icon in pairs(icons) do icon.color = p.accent end
  devicons.set_icon(icons)
  devicons.set_default_icon("", p.accent, "7")
  for i, color in ipairs(a) do vim.g["terminal_color_" .. (i - 1)] = color end
  vim.api.nvim_exec_autocmds("ColorScheme", { pattern = "desktop" })
  -- CodeDiff derives move colors during ColorScheme; use our explicit tints.
  for _, name in ipairs({ "CodeDiffLineMove", "CodeDiffCharMove" }) do
    vim.api.nvim_set_hl(0, name, groups[name])
  end
  vim.cmd("redraw")
end

function M.setup()
  M.apply()
  local group = vim.api.nvim_create_augroup("editor-theme", { clear = true })
  vim.api.nvim_create_autocmd("FocusGained", { group = group, callback = M.apply })
  -- Poll the files, so atomic replacements and an initially missing mode file work.
  for _, path in ipairs({ tokens_path, mode_path }) do
    local watcher = assert(uv.new_fs_poll())
    watcher:start(path, 500, vim.schedule_wrap(M.apply))
    watchers[#watchers + 1] = watcher
  end
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      for _, watcher in ipairs(watchers) do
        watcher:stop()
        watcher:close()
      end
    end,
  })
end

return M
