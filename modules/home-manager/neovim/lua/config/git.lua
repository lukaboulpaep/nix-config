local git = require("gitsigns")

git.setup({
  signs = {
    add = { text = "▎" },
    change = { text = "▎" },
    delete = { text = "" },
    topdelete = { text = "" },
    changedelete = { text = "▎" },
    untracked = { text = "┆" },
  },
  on_attach = function(buf)
    local function map(keys, action, desc)
      vim.keymap.set("n", keys, action, { buffer = buf, desc = desc })
    end
    map("]h", function() git.nav_hunk("next", { target = "all" }) end, "Next Git hunk")
    map("[h", function() git.nav_hunk("prev", { target = "all" }) end, "Previous Git hunk")
    map("<leader>hp", git.preview_hunk, "Preview Git hunk")
    -- Gitsigns stages unstaged hunks and unstages an already-staged hunk.
    map("<leader>hs", git.stage_hunk, "Stage/unstage Git hunk")
    vim.keymap.set("x", "<leader>hs", function()
      local first, last = vim.fn.line("."), vim.fn.line("v")
      git.stage_hunk({ math.min(first, last), math.max(first, last) })
    end, { buffer = buf, desc = "Stage/unstage selected lines" })
    map("<leader>hb", git.blame_line, "Blame current line")
  end,
})
