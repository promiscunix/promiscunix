{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  # Placeholder hardware config. On TheTheater, run:
  #   sudo nixos-generate-config --show-hardware-config > hosts/TheTheater/hardware-configuration.nix
  # to replace this with the real hardware profile.
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [];
  boot.initrd.kernelModules = [];
  boot.kernelModules = [];
  boot.extraModulePackages = [];

  fileSystems = {};
  swapDevices = [];
}


