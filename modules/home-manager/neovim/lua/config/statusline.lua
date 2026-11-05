local function color(group, key, fallback)
  local value = vim.api.nvim_get_hl(0, { name = group, link = false })[key]
  return value and string.format("#%06x", value) or fallback
end

-- Rebuilt by lualine on ColorScheme, including live desktop light/dark changes.
local function theme()
  local foreground = color("Normal", "fg", "#51463B")
  local background = color("Normal", "bg", "#F5EDE2")
  local surface = color("StatusLine", "bg", background)
  local accent = color("Title", "fg", foreground)
  local muted = color("Comment", "fg", foreground)
  local function mode(highlight)
    return {
      a = { fg = background, bg = color(highlight, "fg", accent), gui = "bold" },
      b = { fg = foreground, bg = surface },
      c = { fg = foreground, bg = surface },
    }
  end
  return {
    normal = mode("Title"),
    insert = mode("String"),
    visual = mode("Statement"),
    replace = mode("DiagnosticError"),
    command = mode("DiagnosticWarn"),
    inactive = {
      a = { fg = muted, bg = surface },
      b = { fg = muted, bg = surface },
      c = { fg = muted, bg = surface },
    },
  }
end

local function language_servers()
  if vim.bo.buftype ~= "" or vim.bo.filetype == "" then return "" end
  local names, seen = {}, {}
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
    if not seen[client.name] then
      names[#names + 1] = client.name
      seen[client.name] = true
    end
  end
  table.sort(names)
  return #names > 0 and table.concat(names, ", ") or "LSP: none"
end

require("lualine").setup({
  options = {
    theme = theme,
    globalstatus = true,
    component_separators = "",
    section_separators = "",
  },
  sections = {
    lualine_a = { "mode" },
    lualine_b = {
      { "branch", icon = "" },
      {
        "diff",
        source = function()
          local status = vim.b.gitsigns_status_dict
          if status then
            return { added = status.added, modified = status.changed, removed = status.removed }
          end
        end,
        symbols = { added = " ", modified = " ", removed = " " },
      },
    },
    lualine_c = {
      { "filename", path = 1 },
      { require("config.review-comments").file_note_count, color = "ReviewNote",
        on_click = function() require("config.review-comments").list_file() end },
      { "diagnostics", sources = { "nvim_diagnostic" } },
    },
    lualine_x = { { language_servers, color = "Comment" }, "filetype" },
    lualine_y = { "progress" },
    lualine_z = { "location" },
  },
  extensions = { "neo-tree", "quickfix" },
})
