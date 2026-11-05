require("neo-tree").setup({
  close_if_last_window = true,
  enable_git_status = true,
  enable_diagnostics = true,
  event_handlers = {
    {
      event = "vim_colorscheme",
      handler = function()
        -- Theme changes clear generated fade groups; redraw after Neo-tree
        -- has reset its highlight cache so long filenames get fresh colors.
        vim.schedule(function() require("neo-tree.sources.manager").redraw() end)
      end,
    },
  },
  default_component_configs = {
    git_status = {
      symbols = {
        added = "",
        modified = "",
        deleted = "",
        renamed = "",
        untracked = "",
        ignored = "",
        unstaged = "",
        staged = "",
        conflict = "",
      },
    },
  },
  window = {
    position = "left",
    width = 32,
  },
  filesystem = {
    -- Changing the sidebar's root should not change the project working directory.
    bind_to_cwd = false,
    follow_current_file = { enabled = true },
  },
})
