{
  description = "Personal machine configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { nixpkgs, nixpkgs-unstable, ... }:
    let
      inventory = import ./lib/inventory.nix;
    in {
      nixosConfigurations = builtins.mapAttrs (hostName: hostConfig:
        nixpkgs.lib.nixosSystem {
          system = hostConfig.system;
          specialArgs = {
            inherit hostName hostConfig;
            inherit (inventory) user;
            codex = nixpkgs-unstable.legacyPackages.${hostConfig.system}.codex;
          };
          modules = [
            ./modules/nixos/base.nix
            hostConfig.module
          ];
        }
      ) inventory.nixosHosts;
    };
}
