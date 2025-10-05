{ config, lib, pkgs, inputs, systemInfo, userInfo, userInfos, ... }:

 {
  imports =
    [ 
      ./hardware-configuration.nix
      ../../modules/core/default.nix
      ../../modules/systemLevel/accounts
      inputs.home-manager.nixosModules.home-manager
    ];

  environment.systemPackages = [
    inputs.home-manager.packages.${pkgs.system}.home-manager
  ];

  # VM-only changes: applied ONLY when using `build-vm`
  virtualisation.vmVariant = {
    config = {
      # Fast, guaranteed login just for the VM
      users.users.vmtest = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
        initialPassword = "vmtest";
      };
      users.users.root.initialPassword = "root";
      security.sudo.wheelNeedsPassword = false;

      # Make SSH and port forward work in the VM
      services.openssh.enable = true;
      services.openssh.openFirewall = true;
      virtualisation.forwardPorts = [
        { from = "host"; host.port = 2222; guest.port = 22; }
      ];

      # QEMU knobs
      virtualisation.memorySize = 2048;
      virtualisation.cores = 2;
      virtualisation.graphics = true;

      # Neutralize real-hardware bits so they don't conflict in the VM
      boot.loader.systemd-boot.enable = lib.mkForce false;
      boot.loader.grub.enable = lib.mkForce false;
      fileSystems = lib.mkForce {};
      swapDevices = lib.mkForce [];
    };
  };
  
  system.stateVersion = "25.05"; 
}

