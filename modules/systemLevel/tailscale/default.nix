{
  config,
  lib,
  pkgs,
  repoRoot,
  systemInfo,
  ...
}: let
  cfg = config.promiscunix.tailscale;
  secretFile = repoRoot + "/secrets/tailscale.yaml";
  hasSecret = builtins.pathExists secretFile;
  tagFlag = lib.optionalString (cfg.tags != []) ("--advertise-tags=" + lib.concatStringsSep "," cfg.tags);
  loginFlag = lib.optionalString (cfg.loginServer != "") ("--login-server=" + cfg.loginServer);
  acceptDnsFlag = if cfg.acceptDns then "--accept-dns=true" else "--accept-dns=false";
  acceptRoutesFlag = if cfg.acceptRoutes then "--accept-routes=true" else "--accept-routes=false";
  exitNodeFlag = lib.optionalString cfg.clearExitNode "--exit-node=";
  upFlags = lib.concatStringsSep " " (lib.filter (s: s != "") (
    [
      "--hostname=${systemInfo.hostName}"
      acceptDnsFlag
      acceptRoutesFlag
      exitNodeFlag
      tagFlag
      loginFlag
    ]
    ++ cfg.extraUpFlags
  ));
in {
  imports = [
    ../sops
  ];

  options.promiscunix.tailscale = {
    autoJoin = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Auto-join the tailnet at boot using a SOPS-managed auth key.";
    };
    tags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Tailscale tags to advertise (requires tagged auth key/ACLs).";
    };
    acceptDns = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to accept DNS settings from Tailscale.";
    };
    acceptRoutes = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to accept subnet routes advertised by other Tailscale nodes.";
    };
    clearExitNode = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to clear any selected Tailscale exit node at boot.";
    };
    loginServer = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Custom Tailscale control server (leave empty for default).";
    };
    extraUpFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Extra flags to pass to tailscale up.";
    };
    bootstrapSsh = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Temporarily allow LAN SSH for first bootstrapping; disable after Tailscale is up.";
    };
  };

  config = {
    services.tailscale = {
      enable = true;
      openFirewall = true;
    };

    systemd.services.tailscaled.restartIfChanged = lib.mkDefault false;

    systemd.services.tailscale-network-policy = {
      description = "Enforce local-network-safe Tailscale preferences";
      after = [ "tailscaled.service" "tailscale-autoconnect.service" ];
      requires = [ "tailscaled.service" ];
      partOf = [ "tailscaled.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.tailscale}/bin/tailscale set ${acceptDnsFlag} ${acceptRoutesFlag} ${exitNodeFlag}";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.bootstrapSsh [22];

    promiscunix.tailscale.autoJoin = lib.mkDefault hasSecret;

    assertions = [
      {
        assertion = (!cfg.autoJoin) || hasSecret;
        message = "promiscunix.tailscale.autoJoin is enabled but ${toString secretFile} is missing.";
      }
    ];

    sops.secrets.tailscale_authkey = lib.mkIf (cfg.autoJoin && hasSecret) {
      sopsFile = secretFile;
      owner = "root";
      group = "root";
      mode = "0400";
    };

    systemd.services.tailscale-autoconnect = lib.mkIf (cfg.autoJoin && hasSecret) {
      description = "Tailscale auto-join";
      after = [ "network-online.target" "tailscaled.service" "sops-nix.service" ];
      wants = [ "network-online.target" "tailscaled.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = "30s";
      };
      path = [ pkgs.tailscale pkgs.jq ];
      script = ''
        set -eu
        state="$(tailscale status --json 2>/dev/null | jq -r '.BackendState // ""' 2>/dev/null || true)"
        if [ "$state" = "Running" ]; then
          exit 0
        fi
        key="$(cat ${config.sops.secrets.tailscale_authkey.path})"
        tailscale up --authkey "$key" ${upFlags}
      '';
      wantedBy = [ "multi-user.target" ];
    };
  };
}
