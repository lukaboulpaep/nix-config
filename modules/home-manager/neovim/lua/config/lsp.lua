vim.diagnostic.config({
  severity_sort = true,
  underline = true,
  virtual_text = false,
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = " ",
      [vim.diagnostic.severity.WARN] = " ",
      [vim.diagnostic.severity.INFO] = " ",
      [vim.diagnostic.severity.HINT] = "󰌵 ",
    },
  },
  float = { border = "rounded" },
})

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("editor-lsp", { clear = true }),
  callback = function(event)
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if not client then
      return
    end

    if client:supports_method("textDocument/completion") then
      vim.lsp.completion.enable(true, client.id, event.buf, { autotrigger = true })
    end

    local telescope = require("telescope.builtin")
    for keys, mapping in pairs({
      gd = { telescope.lsp_definitions, "Go to definition" },
      gr = { telescope.lsp_references, "Go to references" },
      gi = { telescope.lsp_implementations, "Go to implementation" },
      gy = { telescope.lsp_type_definitions, "Go to type definition" },
      ["<leader>cs"] = { telescope.lsp_document_symbols, "Search document symbols" },
      ["<leader>cS"] = { telescope.lsp_dynamic_workspace_symbols, "Search workspace symbols" },
    }) do
      vim.keymap.set("n", keys, mapping[1], { buffer = event.buf, desc = mapping[2] })
    end
    vim.keymap.set({ "n", "x" }, "<leader>ca", vim.lsp.buf.code_action,
      { buffer = event.buf, desc = "Code actions" })
    vim.keymap.set("n", "<leader>cr", vim.lsp.buf.rename, { buffer = event.buf, desc = "Rename symbol" })
    vim.keymap.set("n", "<leader>ci", function()
      vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf }),
        { bufnr = event.buf })
    end, { buffer = event.buf, desc = "Toggle inlay hints" })
    vim.keymap.set("n", "<leader>d", vim.diagnostic.open_float,
      { buffer = event.buf, desc = "Show diagnostic" })
    vim.keymap.set("n", "<leader>f", function()
      vim.lsp.buf.format({ async = true })
    end, { buffer = event.buf, desc = "Format buffer" })
  end,
})

-- Definitions are loaded from lsp/<name>.lua; executables come from Nix/PATH.
-- Only enable installed servers, so the editor also works before a rebuild.
for name, executable in pairs({
  lua_ls = "lua-language-server",
  nixd = "nixd",
  gopls = "gopls",
  terraformls = "terraform-ls",
}) do
  if vim.fn.executable(executable) == 1 then
    vim.lsp.enable(name)
  end
end
