# modules/systemLevel/browser-search/default.nix
{
  config,
  lib,
  pkgs,
  ...
}: let
  browserSearchSrc = pkgs.fetchFromGitHub {
    owner = "Johell1NS";
    repo = "browser-search";
    rev = "594d151c6a3de3aa92104cfe9cb5cf7436735e1d";
    hash = "sha256-zl0dvSlpdiAjl/wt4/l/ILA0M3qXzXUDWM4jrb9NknQ=";
  };

  browserSearch = pkgs.buildNpmPackage {
    pname = "browser-search";
    version = "2026-06-30-594d151";
    src = browserSearchSrc;
    npmDepsHash = "sha256-ebTZ/MEgYNw16r3FIdjXju+v6I1MaqFopXqklu+D5Xs=";
    npmFlags = ["--ignore-scripts"];
    dontNpmBuild = true;

    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/browser-search
      cp -R . $out/share/browser-search
      runHook postInstall
    '';
  };

  browserSearchCloakFetch = pkgs.writeShellApplication {
    name = "browser-search-cloak-fetch";
    runtimeInputs = [pkgs.nodejs];
    text = ''
      export HOME="''${BROWSER_SEARCH_HOME:-/var/lib/hermes}"
      exec ${pkgs.nodejs}/bin/node ${browserSearch}/share/browser-search/scripts/cloak/cloak-fetch.mjs "$@"
    '';
  };

  browserSearchCloakScript = pkgs.writeShellApplication {
    name = "browser-search-cloak-script";
    runtimeInputs = [pkgs.nodejs];
    text = ''
      export HOME="''${BROWSER_SEARCH_HOME:-/var/lib/hermes}"
      exec ${pkgs.nodejs}/bin/node ${browserSearch}/share/browser-search/scripts/cloak/cloak-script.mjs "$@"
    '';
  };

  browserSearchCheck = pkgs.writeShellApplication {
    name = "browser-search-check";
    runtimeInputs = [pkgs.curl pkgs.jq pkgs.nodejs pkgs.coreutils];
    text = ''
      set +e
      failed=0

      printf 'SearXNG: '
      searx_code=$(curl -sS -G -o /tmp/browser-search-searx.json -w '%{http_code}' \
        http://127.0.0.1:8080/search \
        --data-urlencode 'q=health' \
        --data-urlencode 'format=json' 2>/dev/null)
      if [ "$searx_code" = 200 ] && jq -e '.results | type == "array"' /tmp/browser-search-searx.json >/dev/null 2>&1; then
        echo "ok ($searx_code, $(jq '.results | length' /tmp/browser-search-searx.json) results)"
      else
        echo "failed ($searx_code)"
        failed=1
      fi

      printf 'Camofox: '
      camofox_json=$(curl -sS --max-time 5 http://127.0.0.1:9377/health 2>/dev/null)
      if printf '%s' "$camofox_json" | jq -e 'type == "object"' >/dev/null 2>&1; then
        echo "ok ($camofox_json)"
      else
        echo "failed"
        failed=1
      fi

      printf 'CloakBrowser: '
      if ${browserSearchCloakFetch}/bin/browser-search-cloak-fetch --version >/dev/null 2>&1; then
        echo "ok"
      else
        echo "failed"
        failed=1
      fi

      exit "$failed"
    '';
  };

  hermesSkill = pkgs.writeText "browser-search-hermes-skill.md" ''
    ---
    name: browser-search
    description: NixOS-native local web research stack: SearXNG search, Camofox browser API, and CloakBrowser fallback.
    ---

    # Browser Search on Gibbs

    Use this skill whenever live web research needs search plus browser-backed verification.

    ## Local services

    - SearXNG: `http://127.0.0.1:8080`
    - Camofox: `http://127.0.0.1:9377`
    - CloakBrowser wrappers: `browser-search-cloak-fetch`, `browser-search-cloak-script`
    - Health check: `browser-search-check`

    The stack is managed by NixOS, not by ad-hoc Docker/npm commands. Do not run upstream install scripts. If a service is down, inspect/rebuild the NixOS config and systemd/OCI units.

    ## SearXNG search

    Always URL-encode queries:

    ```bash
    curl -s -G "http://127.0.0.1:8080/search" \
      --data-urlencode "q=<query>" \
      --data-urlencode "format=json" | jq .
    ```

    ## Camofox browser API

    General pattern: create tab, snapshot/evaluate/interact, close tab. Use `CAMOFOX_API_KEY` from the Hermes service environment for endpoints that require bearer auth.

    ```bash
    curl -s -X POST "http://127.0.0.1:9377/tabs" \
      -H 'Content-Type: application/json' \
      -d '{"userId":"hermes","sessionKey":"default","url":"https://example.com"}'

    curl -s "http://127.0.0.1:9377/tabs/<tabId>/snapshot?userId=hermes"

    curl -s -X POST "http://127.0.0.1:9377/tabs/<tabId>/evaluate" \
      -H 'Content-Type: application/json' \
      -H "Authorization: Bearer $CAMOFOX_API_KEY" \
      -d '{"userId":"hermes","expression":"document.title"}'

    curl -s -X DELETE "http://127.0.0.1:9377/tabs/<tabId>?userId=hermes"
    ```

    ## CloakBrowser fallback

    Use only when Camofox is blocked or cannot load enough content:

    ```bash
    browser-search-cloak-fetch "https://example.com" --format text
    browser-search-cloak-fetch "https://example.com" --scroll --retry 1 --timeout 45000
    ```

    CloakBrowser has SSRF protection enabled by default. Do not pass `--unsafe` unless Dale explicitly asks to access a local/internal URL.

    ## Rules

    - Search first, browse second.
    - Prefer SearXNG results when snippets are enough.
    - Use Camofox for normal JS-heavy pages and structured extraction.
    - Escalate to CloakBrowser only for protected/blocked sites.
    - Do not use Camofox/CloakBrowser for social media sites requiring login.
    - Do not bypass paywalls or login systems.
  '';

  envFile = "/var/lib/hermes/browser-search.env";
in {
  services.searx = {
    enable = true;
    openFirewall = false;
    environmentFile = envFile;
    settings = {
      use_default_settings = true;
      server = {
        bind_address = "127.0.0.1";
        port = 8080;
        secret_key = "$SEARX_SECRET_KEY";
        public_instance = false;
      };
      search = {
        formats = ["html" "json"];
      };
    };
  };

  virtualisation.oci-containers.backend = lib.mkDefault "docker";
  virtualisation.oci-containers.containers.camofox-browser = {
    image = "ghcr.io/jo-inc/camofox-browser@sha256:3ab61b4742105922aab6f8c99460f55563b6f93e906975383ddce16ec8917f3f";
    autoStart = true;
    ports = ["127.0.0.1:9377:9377"];
    environment = {
      CAMOFOX_PORT = "9377";
      CAMOFOX_CRASH_REPORT_ENABLED = "false";
      NODE_ENV = "production";
    };
    environmentFiles = [envFile];
    extraOptions = [
      "--memory=2g"
      "--cpus=2"
      "--pids-limit=200"
      "--security-opt=no-new-privileges"
      "--tmpfs=/tmp"
      "--tmpfs=/home/camofox/.cache"
    ];
  };

  environment.systemPackages = [
    browserSearch
    browserSearchCloakFetch
    browserSearchCloakScript
    browserSearchCheck
  ];

  systemd.services.hermes-agent.serviceConfig.EnvironmentFile = [envFile];

  system.activationScripts."browser-search-secrets-and-skill" = ''
    set -eu
    install -d -m 0750 -o root -g root /var/lib/hermes

    if [ ! -f ${envFile} ]; then
      (
        umask 077
        {
          printf 'SEARX_SECRET_KEY='
          ${pkgs.openssl}/bin/openssl rand -hex 32
          printf 'CAMOFOX_API_KEY='
          ${pkgs.openssl}/bin/openssl rand -hex 32
          printf 'CAMOFOX_ADMIN_KEY='
          ${pkgs.openssl}/bin/openssl rand -hex 32
        } > ${envFile}
      )
      chown root:root ${envFile}
      chmod 0600 ${envFile}
    fi

    install -d -m 0755 -o gibbs -g gibbs /var/lib/hermes/.hermes/skills/browser-search
    install -m 0644 -o gibbs -g gibbs ${hermesSkill} /var/lib/hermes/.hermes/skills/browser-search/SKILL.md
  '';
}
