return {
  cmd = { "lua-language-server" },
  filetypes = { "lua" },
  root_markers = { ".luarc.json", ".luarc.jsonc", "init.lua", ".git" },
  on_init = function(client)
    -- Neovim API types belong to this config, not to every Lua project.
    local root = client.config.root_dir
    local config_root = vim.uv.fs_realpath(vim.fn.stdpath("config"))
    if not root or not config_root then
      return
    end
    root = vim.uv.fs_realpath(root) or root
    -- A parent workspace also publishes diagnostics for unopened Lua files.
    -- Leave this nested config to its own client with Neovim's API library.
    if vim.startswith(config_root, root .. "/") then
      client.settings = vim.tbl_deep_extend("force", client.settings, {
        Lua = { workspace = { ignoreDir = { config_root:sub(#root + 2) } } },
      })
      client:notify("workspace/didChangeConfiguration", { settings = client.settings })
      return
    end
    if root ~= config_root then
      return
    end
    if vim.uv.fs_stat(root .. "/.luarc.json") or vim.uv.fs_stat(root .. "/.luarc.jsonc") then
      return
    end

    client.settings = vim.tbl_deep_extend("force", client.settings, {
      Lua = {
        runtime = {
          version = "LuaJIT",
          -- Keep the plugin 'review' distinct from our 'config.review'.
          path = { "?.lua", "?/init.lua", "lua/?.lua", "lua/?/init.lua" },
          pathStrict = true,
        },
        workspace = {
          checkThirdParty = false,
          library = { vim.env.VIMRUNTIME },
        },
      },
    })
    client:notify("workspace/didChangeConfiguration", { settings = client.settings })
  end,
}
