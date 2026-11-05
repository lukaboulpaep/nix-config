local function is_empty_buffer(buf)
  return vim.api.nvim_buf_get_name(buf) == ""
      and not vim.bo[buf].modified
      and vim.api.nvim_buf_line_count(buf) == 1
      and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
end

local review_group = vim.api.nvim_create_augroup("DesktopReviewBuffers", { clear = true })
vim.api.nvim_create_autocmd("BufAdd", {
  group = review_group,
  callback = function(event)
    if require("codediff.ui.lifecycle").get_session(vim.api.nvim_get_current_tabpage()) then
      vim.b[event.buf].desktop_review_buffer = true
    end
  end,
})
vim.api.nvim_create_autocmd("BufEnter", {
  group = review_group,
  callback = function(event)
    -- Opening a reviewed file in an ordinary editing tab makes it a normal
    -- buffer again. Merely browsing the review never fills the bufferline.
    if not require("codediff.ui.lifecycle").get_session(vim.api.nvim_get_current_tabpage()) then
      vim.b[event.buf].desktop_review_buffer = nil
    end
  end,
})

local function show_buffer(buf)
  return vim.bo[buf].buftype == ""
      and not is_empty_buffer(buf)
      and (not vim.b[buf].desktop_review_buffer or vim.bo[buf].modified)
end

local function close_buffer(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= "" then return end

  local discard = false
  if vim.bo[buf].modified then
    local name = vim.api.nvim_buf_get_name(buf)
    local choice = vim.fn.confirm("Save changes to " .. (name ~= "" and name or "[No Name]") .. "?",
      "&Save\n&Discard\n&Cancel", 3)
    if choice == 1 then
      local ok, err = pcall(vim.api.nvim_buf_call, buf, function() vim.cmd.write() end)
      if not ok then
        vim.notify(tostring(err), vim.log.levels.ERROR)
        return
      end
      if vim.bo[buf].modified then return end
    elseif choice == 2 then
      discard = true
    else
      return
    end
  end

  -- Replace the file in every window before deleting it. :bdelete can close
  -- the last editing split, leaving Neo-tree to quit the remaining window.
  local replacement
  for _, info in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
    if info.bufnr ~= buf and show_buffer(info.bufnr) then
      if not replacement or info.lastused > replacement.lastused then replacement = info end
    end
  end
  local windows = vim.fn.win_findbuf(buf)
  if #windows > 0 then
    local next_buf = replacement and replacement.bufnr or vim.api.nvim_create_buf(true, false)
    for _, win in ipairs(windows) do
      vim.api.nvim_win_call(win, function()
        vim.cmd("hide buffer " .. next_buf)
      end)
    end
  end
  vim.api.nvim_buf_delete(buf, { force = discard })
end

require("bufferline").setup({
  options = {
    mode = "buffers",
    custom_filter = show_buffer,
    diagnostics = "nvim_lsp",
    separator_style = "thin",
    show_close_icon = false,
    close_command = close_buffer,
    right_mouse_command = close_buffer,
    always_show_bufferline = true,
    offsets = {
      { filetype = "neo-tree", text = "Files", text_align = "left", highlight = "Directory" },
    },
  },
})

vim.keymap.set("n", "<S-h>", "<Cmd>BufferLineCyclePrev<CR>", { desc = "Previous buffer" })
vim.keymap.set("n", "<S-l>", "<Cmd>BufferLineCycleNext<CR>", { desc = "Next buffer" })
vim.keymap.set("n", "<leader>bb", "<Cmd>BufferLinePick<CR>", { desc = "Pick buffer" })
vim.keymap.set("n", "<leader>bd", function() close_buffer() end, { desc = "Close buffer" })
vim.keymap.set("n", "<leader>bp", "<Cmd>BufferLineTogglePin<CR>", { desc = "Pin buffer" })

return { close = close_buffer }
