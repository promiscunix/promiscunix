{
  config,
  pkgs,
  ...
}: {
  sops = {
    defaultSopsFile = ./secrets/user-mapping.yaml;
    age.keyFile = "/var/lib/sops-nix/key.txt"; # Or your preferred location

    secrets.user-mapping = {
      # The secret will be decrypted to a temporary location
      # Access it via: config.sops.secrets.user-mapping.path
      # owner = "guacamole"; # Set appropriate owner
      # group = "guacamole"; # Set appropriate group
      mode = "0440"; # Set appropriate permissions   # The decrypted file will be available at runtime
    };
  };

  # Use it in your config:
  # The decrypted content is at: config.sops.secrets.user-mapping.path
}
