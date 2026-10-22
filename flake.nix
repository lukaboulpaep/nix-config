{
  description = "Personal machine configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nixpkgs-unstable, home-manager, nix-darwin, ... }:
    let
      inventory = import ./lib/inventory.nix;
      specialArgsFor = hostName: hostConfig: {
        inherit hostName hostConfig;
        user = inventory.user // { name = hostConfig.userName; };
      };
      homeModule = hostConfig: {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          extraSpecialArgs = {
            inherit hostConfig;
            user = inventory.user // { name = hostConfig.userName; };
            codex = nixpkgs-unstable.legacyPackages.${hostConfig.system}.codex;
          };
          users.${hostConfig.userName} = import hostConfig.homeModule;
        };
      };
    in {
      nixosConfigurations = builtins.mapAttrs (hostName: hostConfig:
        nixpkgs.lib.nixosSystem {
          system = hostConfig.system;
          specialArgs = specialArgsFor hostName hostConfig;
          modules = [
            home-manager.nixosModules.home-manager
            (homeModule hostConfig)
            hostConfig.module
          ];
        }
      ) inventory.nixosHosts;
      darwinConfigurations = builtins.mapAttrs (hostName: hostConfig:
        nix-darwin.lib.darwinSystem {
          specialArgs = specialArgsFor hostName hostConfig;
          modules = [
            { nixpkgs.hostPlatform = hostConfig.system; }
            home-manager.darwinModules.home-manager
            (homeModule hostConfig)
            hostConfig.module
          ];
        }
      ) inventory.darwinHosts;
    };
}
