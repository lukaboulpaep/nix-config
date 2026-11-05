return {
  cmd = { "nixd" },
  filetypes = { "nix" },
  root_markers = { "flake.nix", ".git" },
  settings = {
    nixd = { formatting = { command = { "nixfmt" } } },
  },
  on_init = function(client)
    -- Use this repository's pinned packages and module options here only.
    -- Other projects retain nixd's defaults and can supply their own settings.
    if client.config.root_dir ~= "/etc/nixos" then return end
    local flake = '(builtins.getFlake "path:/etc/nixos")'
    local systems = vim.fn.has("mac") == 1 and "darwinConfigurations" or "nixosConfigurations"
    local host = flake .. "." .. systems .. "." .. vim.json.encode(vim.uv.os_gethostname())
    client.settings = vim.tbl_deep_extend("force", client.settings, {
      nixd = {
        nixpkgs = { expr = "import " .. flake .. ".inputs.nixpkgs { }" },
        options = {
          system = { expr = host .. ".options" },
          home_manager = { expr = host .. ".options.home-manager.users.type.getSubOptions []" },
        },
      },
    })
    client:notify("workspace/didChangeConfiguration", { settings = client.settings })
  end,
}
