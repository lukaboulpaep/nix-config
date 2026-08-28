{
  description = "Luka's modular NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # hyprmoncfg is not in the pinned 26.05 package set yet.
    hyprmoncfg-nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:danth/stylix/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    apple-fonts.url = "github:Lyndeno/apple-fonts.nix";

    nix-flatpak.url = "github:gmodena/nix-flatpak/v0.7.0";

    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    herdr = {
      url = "github:herdrdev/herdr";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    llm-agents.url = "github:numtide/llm-agents.nix";
  };

  outputs =
    inputs@{
      nixpkgs,
      home-manager,
      stylix,
      apple-fonts,
      ...
    }:
    let
      inventory = import ./lib/inventory.nix;

      mkHomeUser =
        hostConfig: username:
        let
          userConfig = inventory.users.${username};
        in
        {
          imports = [ ./home ] ++ map (profile: ./home/profiles + "/${profile}.nix") userConfig.profiles;
          _module.args = {
            inherit hostConfig userConfig;
          };
        };

      mkHost =
        hostName: hostConfig:
        nixpkgs.lib.nixosSystem {
          system = hostConfig.system;
          specialArgs = {
            inherit
              hostConfig
              hostName
              inputs
              inventory
              ;
          };

          modules = [
            {
              nixpkgs.overlays = [
                apple-fonts.overlays.default
              ];
            }

            stylix.nixosModules.stylix
            hostConfig.module
            home-manager.nixosModules.home-manager

            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.extraSpecialArgs = {
                inherit hostConfig inputs inventory;
              };
              home-manager.users = builtins.listToAttrs (
                map (username: {
                  name = username;
                  value = mkHomeUser hostConfig username;
                }) hostConfig.users
              );
            }
          ];
        };
    in
    {
      nixosConfigurations = builtins.mapAttrs mkHost inventory.hosts;
    };
}
