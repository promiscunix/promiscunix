# modules/systemLevel/hermes/default.nix
{
  config,
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.hermes-agent.nixosModules.default
  ];

  services.hermes-agent = {
    enable = true;

    user = "gibbs";
    group = "gibbs";
    createUser = true;

    stateDir = "/var/lib/hermes";
    workingDirectory = "/var/lib/hermes/workspace";

    addToSystemPackages = true;

    # Include Telegram/Discord/Slack gateway dependencies in the sealed Hermes
    # Python environment. Without this, the NixOS service starts after reboot
    # but the Telegram adapter is unavailable unless a manual PYTHONPATH hack is
    # applied.
    extraDependencyGroups = ["messaging"];

    # Secret env file. The NixOS module merges this into
    # /var/lib/hermes/.hermes/.env during activation.
    environmentFiles = [
      "/var/lib/hermes/env"
    ];

    settings = {
      model = {
        default = "gpt-5.5";
        provider = "openai-codex";
      };

      fallback_model = {
        provider = "kimi-coding";
        model = "kimi-k2.6";
      };

      telegram = {
        allow_from = ["8028674484"];
      };

      terminal = {
        backend = "local";
        timeout = 180;
        cwd = "/var/lib/hermes/workspace";
      };

      compression = {
        enabled = true;
        threshold = 0.85;
      };

      # Keep Telegram sessions lean: avoid exposing every integration/schema by
      # default. Add heavyweight toolsets (browser, image/video generation,
      # Discord/admin, Home Assistant, etc.) only when needed.
      toolsets = [
        "terminal"
        "file"
        "web"
        "code_execution"
        "vision"
        "skills"
        "memory"
        "session_search"
        "cronjob"
        "messaging"
        "delegation"
        "todo"
        "clarify"
      ];

      # Pilot: enable Mugen0815/hermes-cortex from
      # /var/lib/hermes/.hermes/plugins/cortex. Runtime hooks remain disabled
      # in /var/lib/hermes/.hermes/cortex/config.yaml; this only makes the
      # explicit vault_search/vault_read_note/vault_build_context tools visible.
      plugins.enabled = ["cortex"];

      agent = {
        max_turns = 60;
        verbose = false;
      };
    };

    documents = {
      "USER.md" = ''
        # User Profile

        The user is Dale Appleby.

        Dale is a Parts Manager at a Chrysler/Stellantis dealership in Canada.

        Important work context:
        - CDK reports
        - parts inventory control
        - stale stock cleanup
        - BSL tuning
        - FCA invoice parsing
        - special order tracking
        - parts/service communication

        Technical context:
        - NixOS
        - flakes
        - Home Manager
        - Tailscale
        - local agents and automation

        Preferred response style:
        - direct
        - practical
        - no vague motivational filler
        - copy-pasteable commands when possible
      '';
    };

    extraPackages = with pkgs; [
      git
      curl
      jq
      ripgrep
      fd
      bat
      eza
      python3
      nodejs
      ffmpeg
    ];

    restart = "always";
    restartSec = 5;
  };

  # Let the Hermes service user work inside the user's private home directory
  # without taking ownership away from the real user. The robust model is:
  # - damajha remains the owner of human-facing content
  # - gibbs gets explicit ACL access where Hermes needs to read/write
  # - default ACLs preserve shared access for future files created by either side
  systemd.services.hermes-agent.environment.PYTHONPATH = "/var/lib/hermes/.hermes/plugins/cortex/.hermes-venv/lib/python3.12/site-packages:/var/lib/hermes/python-patches";
  systemd.services.hermes-agent.environment.LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.zlib}/lib";
  systemd.services.hermes-agent.environment.CORTEX_CONFIG = "/var/lib/hermes/.hermes/cortex/config.yaml";

  systemd.services.hermes-agent.serviceConfig.TimeoutStopSec = "210s";

  system.activationScripts."hermes-user-content-acl" = ''
    if [ -d /home/damajha ]; then
      ${pkgs.acl}/bin/setfacl -m u:gibbs:x /home/damajha || true
    fi

    if [ -d /home/damajha/nixfiles ]; then
      ${pkgs.acl}/bin/setfacl -R -m u:gibbs:rwX /home/damajha/nixfiles || true
      ${pkgs.acl}/bin/setfacl -R -d -m u:gibbs:rwX /home/damajha/nixfiles || true
    fi

    if [ -d /home/damajha/Documents/Obsidian\ Vault ]; then
      chown -R damajha:users /home/damajha/Documents/Obsidian\ Vault || true
      ${pkgs.acl}/bin/setfacl -R -m u:gibbs:rwX,u:damajha:rwX /home/damajha/Documents/Obsidian\ Vault || true
      ${pkgs.acl}/bin/setfacl -R -d -m u:gibbs:rwX,u:damajha:rwX /home/damajha/Documents/Obsidian\ Vault || true
    fi

    if [ -d /home/damajha/projects/docujest-master ]; then
      chown -R damajha:users /home/damajha/projects/docujest-master || true
      ${pkgs.acl}/bin/setfacl -R -m u:gibbs:rwX,u:damajha:rwX /home/damajha/projects/docujest-master || true
      ${pkgs.acl}/bin/setfacl -R -d -m u:gibbs:rwX,u:damajha:rwX /home/damajha/projects/docujest-master || true
    fi
  '';
}
