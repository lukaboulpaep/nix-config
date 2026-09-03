{
  hostConfig,
  pkgs,
  ...
}:

{
  boot.kernelModules = [ hostConfig.hardware.virtualizationModule ];

  users.groups.kvm = { };
  users.users = builtins.listToAttrs (
    map (username: {
      name = username;
      value.extraGroups = [ "kvm" ];
    }) hostConfig.users
  );

  environment.systemPackages = [
    # Pi supplies its own pinned Node runtime; Gondolin uses QEMU for its VM.
    pkgs.qemu_kvm

    # Host-side tools used by the Gondolin Pi wrapper and SSH agent checks.
    pkgs.git
    pkgs.nix
    pkgs.openssh
  ];
}
