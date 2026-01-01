# Base SOPS configuration module
# Individual modules (like guacamole) import sops-nix and define their own secrets.
# This module provides shared documentation and common settings.
{
  config,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  sops = {
    # Default key file location for age decryption
    age.keyFile = "/var/lib/sops-nix/key.txt";
  };

  # Ensure the key file directory exists
  system.activationScripts.sops-key-dir = ''
    mkdir -p /var/lib/sops-nix
    chmod 700 /var/lib/sops-nix
  '';
}
