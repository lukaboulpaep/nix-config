-- Nix supplies parsers and matching queries in the standard site runtime.
-- Native highlighting also works for parsers installed for additional languages.
-- Native Neovim does not inherit nvim-treesitter's filetype aliases.
vim.treesitter.language.register("bash", "sh")
vim.treesitter.language.register("javascript", "javascriptreact")
vim.treesitter.language.register("tsx", "typescriptreact")
vim.treesitter.language.register("terraform", "terraform-vars")
vim.treesitter.language.register("qmljs", "qml")

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("editor-treesitter", { clear = true }),
  callback = function(event)
    if vim.bo[event.buf].buftype ~= "" then return end
    local lang = vim.treesitter.language.get_lang(vim.bo[event.buf].filetype)
    if not lang then return end
    local ok, loaded = pcall(vim.treesitter.language.add, lang)
    if ok and loaded then
      vim.treesitter.start(event.buf, lang)
    end
  end,
})
