{ lib, config, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkIf mkOption types;
  cfg = config.services.dispatcharr;
in
{
  options.services.dispatcharr = {
    enable = mkEnableOption "Dispatcharr (containerized via oci-containers)";

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/dispatcharr";
      description = "Host directory for Dispatcharr persistent data, mounted at /data in the container.";
    };

    port = mkOption {
      type = types.int;
      default = 9191;
      description = "Host TCP port to expose Dispatcharr web UI.";
    };

    imageTag = mkOption {
      type = types.str;
      default = "latest";
      description = "Dispatcharr container image tag from ghcr.io/dispatcharr/dispatcharr.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open the firewall for the Dispatcharr web UI port.";
    };

    backend = mkOption {
      type = types.enum [ "docker" "podman" ];
      default = "docker";
      description = "OCI backend used by virtualisation.oci-containers.";
    };

    extraEnv = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "Additional environment variables for the container.";
    };
  };

  config = mkIf cfg.enable {
    # Enable chosen OCI backend
    virtualisation.oci-containers.backend = cfg.backend;
    virtualisation.docker.enable = mkIf (cfg.backend == "docker") true;
    virtualisation.podman.enable = mkIf (cfg.backend == "podman") true;

    # Container definition
    virtualisation.oci-containers.containers.dispatcharr = {
      image = "ghcr.io/dispatcharr/dispatcharr:${cfg.imageTag}";
      ports = [ "${toString cfg.port}:9191" ];
      volumes = [ "${cfg.dataDir}:/data" ];
      environment = cfg.extraEnv;
      restartPolicy = "always";
    };

    # Ensure data directory exists
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root -"
    ];

    # Open firewall if requested
    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [ cfg.port ];
  };
}


