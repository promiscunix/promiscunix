# Reversible reading-services pilot for theLibrary.
# Existing ebook and audiobook collections are mounted read-only. All writable
# library paths are confined to /mnt/storage/@library-pilot.
{ config, lib, pkgs, ... }:
let
  tailnetAddress = "100.118.124.40";
  stateRoot = "/persist/library-services";
  pilotRoot = "/mnt/storage/@library-pilot";
  appSecretFile = "${stateRoot}/secrets/grimmory-app.env";
  databaseSecretFile = "${stateRoot}/secrets/grimmory-db.env";

  hardenedOptions = [
    "--cap-drop=all"
    "--security-opt=no-new-privileges"
  ];

  ensureGrimmorySecrets = pkgs.writeShellScript "ensure-grimmory-secrets" ''
    set -eu
    umask 077
    secret_dir=${lib.escapeShellArg "${stateRoot}/secrets"}
    credentials_file="$secret_dir/grimmory-credentials"
    app_secret_file=${lib.escapeShellArg appSecretFile}
    database_secret_file=${lib.escapeShellArg databaseSecretFile}
    ${pkgs.coreutils}/bin/mkdir -p "$secret_dir"

    if [ ! -e "$credentials_file" ]; then
      database_password="$(${pkgs.openssl}/bin/openssl rand -hex 32)"
      root_password="$(${pkgs.openssl}/bin/openssl rand -hex 32)"
      credentials_temporary="$(${pkgs.coreutils}/bin/mktemp "$secret_dir/.grimmory-credentials.XXXXXX")"
      ${pkgs.coreutils}/bin/printf '%s\n%s\n' "$database_password" "$root_password" > "$credentials_temporary"
      ${pkgs.coreutils}/bin/chown root:root "$credentials_temporary"
      ${pkgs.coreutils}/bin/chmod 0600 "$credentials_temporary"
      ${pkgs.coreutils}/bin/mv "$credentials_temporary" "$credentials_file"
    fi

    test "$(${pkgs.coreutils}/bin/stat -c '%U:%G:%a' "$credentials_file")" = 'root:root:600'
    {
      IFS= read -r database_password
      IFS= read -r root_password
    } < "$credentials_file"
    test -n "$database_password" && test -n "$root_password"

    app_temporary="$(${pkgs.coreutils}/bin/mktemp "$secret_dir/.grimmory-app.env.XXXXXX")"
    database_temporary="$(${pkgs.coreutils}/bin/mktemp "$secret_dir/.grimmory-db.env.XXXXXX")"
    cleanup() {
      ${pkgs.coreutils}/bin/rm -f "$app_temporary" "$database_temporary"
    }
    trap cleanup EXIT HUP INT TERM

    ${pkgs.coreutils}/bin/printf '%s\n' \
      "DATABASE_PASSWORD=$database_password" > "$app_temporary"
    ${pkgs.coreutils}/bin/printf '%s\n' \
      'MARIADB_DATABASE=grimmory' \
      'MARIADB_USER=grimmory' \
      "MARIADB_PASSWORD=$database_password" \
      "MARIADB_ROOT_PASSWORD=$root_password" > "$database_temporary"
    ${pkgs.coreutils}/bin/chown root:root "$app_temporary" "$database_temporary"
    ${pkgs.coreutils}/bin/chmod 0600 "$app_temporary" "$database_temporary"
    ${pkgs.coreutils}/bin/mv "$app_temporary" "$app_secret_file"
    ${pkgs.coreutils}/bin/mv "$database_temporary" "$database_secret_file"
    trap - EXIT HUP INT TERM

    test "$(${pkgs.coreutils}/bin/stat -c '%U:%G:%a' "$app_secret_file")" = 'root:root:600'
    test "$(${pkgs.coreutils}/bin/stat -c '%U:%G:%a' "$database_secret_file")" = 'root:root:600'
    ${pkgs.gnugrep}/bin/grep -Eq '^DATABASE_PASSWORD=.+$' "$app_secret_file"
    for key in MARIADB_DATABASE MARIADB_USER MARIADB_PASSWORD MARIADB_ROOT_PASSWORD; do
      ${pkgs.gnugrep}/bin/grep -Eq "^''${key}=.+$" "$database_secret_file"
    done
  '';

  ordinaryContainerUnits = [
    "podman-kavita"
    "podman-audiobookshelf"
    "podman-bindery"
  ];
in
{
  virtualisation.podman.enable = true;
  virtualisation.oci-containers.backend = "podman";

  virtualisation.oci-containers.containers = {
    grimmory-db = {
      image = "docker.io/library/mariadb@sha256:ae6119716edac6998ae85508431b3d2e666530ddf4e94c61a10710caec9b0f71";
      pull = "missing";
      environment = {
        TZ = "America/Vancouver";
      };
      environmentFiles = [ databaseSecretFile ];
      volumes = [ "${stateRoot}/grimmory/db:/var/lib/mysql" ];
      networks = [ "library-services" ];
      extraOptions = hardenedOptions ++ [
        "--cap-add=chown,dac_override,fowner,setgid,setuid"
        "--health-cmd=healthcheck.sh --connect --innodb_initialized"
        "--health-interval=2s"
        "--health-timeout=5s"
        "--health-retries=30"
        "--health-start-period=10s"
      ];
    };

    grimmory = {
      image = "ghcr.io/grimmory-tools/grimmory@sha256:fffd0ae0bfccd64ca00441e8fa58a14e286b9115e5df1cb47eecf294ad09e6ff";
      pull = "missing";
      dependsOn = [ "grimmory-db" ];
      environment = {
        USER_ID = "1000";
        GROUP_ID = "100";
        TZ = "America/Vancouver";
        DATABASE_URL = "jdbc:mariadb://grimmory-db:3306/grimmory";
        DATABASE_USERNAME = "grimmory";
        DISK_TYPE = "NETWORK";
        API_DOCS_ENABLED = "false";
      };
      environmentFiles = [ appSecretFile ];
      ports = [ "${tailnetAddress}:6060:6060" ];
      volumes = [
        "${stateRoot}/grimmory/data:/app/data"
        "${pilotRoot}/ebooks:/books"
        "${pilotRoot}/bookdrop:/bookdrop"
        "/mnt/storage/@books:/legacy-books:ro"
      ];
      networks = [ "library-services" ];
      extraOptions = hardenedOptions ++ [
        "--cap-add=chown,dac_override,setgid,setuid"
      ];
    };

    kavita = {
      image = "ghcr.io/kareadita/kavita@sha256:31181a32f0dda73cae68721867028a7253d57881b58bea5754cd9e578e75421a";
      pull = "missing";
      user = "1000:100";
      environment.TZ = "America/Vancouver";
      ports = [ "${tailnetAddress}:5000:5000" ];
      volumes = [
        "${stateRoot}/kavita/config:/kavita/config"
        "/mnt/storage/@books:/legacy-books:ro"
        "${pilotRoot}/ebooks:/pilot-books:ro"
      ];
      extraOptions = hardenedOptions;
    };

    audiobookshelf = {
      image = "ghcr.io/advplyr/audiobookshelf@sha256:180acad33d69c99ed208676465d8edcb268fa46967735579a7810859885b1a8e";
      pull = "missing";
      user = "1000:100";
      environment = {
        TZ = "America/Vancouver";
        PORT = "13378";
      };
      ports = [ "${tailnetAddress}:13378:13378" ];
      volumes = [
        "${stateRoot}/audiobookshelf/config:/config"
        "${stateRoot}/audiobookshelf/metadata:/metadata"
        "/mnt/storage/@audiobooks:/legacy-audiobooks:ro"
        "${pilotRoot}/audiobooks:/audiobooks:ro"
      ];
      extraOptions = hardenedOptions;
    };

    bindery = {
      image = "ghcr.io/vavallee/bindery@sha256:c4ebfc5470e1eb7e347a4a83f1c38f7ca1d4389f673287831413ba5b900cd936";
      pull = "missing";
      user = "1000:100";
      environment = {
        TZ = "America/Vancouver";
        BINDERY_LOG_LEVEL = "info";
        BINDERY_TELEMETRY_DISABLED = "true";
        BINDERY_PUID = "1000";
        BINDERY_PGID = "100";
        BINDERY_LIBRARY_DIR = "/data/ebooks";
        BINDERY_AUDIOBOOK_DIR = "/data/audiobooks";
        BINDERY_DOWNLOAD_DIR = "/data/downloads";
        BINDERY_AUDIOBOOK_DOWNLOAD_DIR = "/data/downloads";
      };
      ports = [ "${tailnetAddress}:8788:8787" ];
      volumes = [
        "${stateRoot}/bindery/config:/config"
        "${pilotRoot}:/data"
      ];
      extraOptions = hardenedOptions ++ [
        "--read-only"
        "--tmpfs=/tmp:rw,nosuid,nodev,noexec,size=64m"
      ];
    };
  };

  systemd.tmpfiles.rules = [
    "d ${stateRoot} 0750 root users -"
    "d ${stateRoot}/secrets 0700 root root -"
    "d ${stateRoot}/grimmory 0750 damajha users -"
    "d ${stateRoot}/grimmory/data 0750 damajha users -"
    "d ${stateRoot}/grimmory/db 0700 root root -"
    "d ${stateRoot}/kavita 0750 damajha users -"
    "d ${stateRoot}/kavita/config 0750 damajha users -"
    "d ${stateRoot}/audiobookshelf 0750 damajha users -"
    "d ${stateRoot}/audiobookshelf/config 0750 damajha users -"
    "d ${stateRoot}/audiobookshelf/metadata 0750 damajha users -"
    "d ${stateRoot}/bindery 0750 damajha users -"
    "d ${stateRoot}/bindery/config 0750 damajha users -"
  ];

  users.users.damajha.uid = lib.mkDefault 1000;

  systemd.services = lib.genAttrs ordinaryContainerUnits
    (_: {
      requires = [ "mnt-storage.mount" "library-services-storage-layout.service" ];
      after = [ "mnt-storage.mount" "library-services-storage-layout.service" "network-online.target" "tailscaled.service" ];
      wants = [ "network-online.target" "tailscaled.service" ];
    }) // {
    library-services-storage-layout = {
      description = "Create reading-services pilot directories on mounted storage";
      requires = [ "mnt-storage.mount" ];
      after = [ "mnt-storage.mount" ];
      before = map (unit: "${unit}.service") ordinaryContainerUnits;
      unitConfig.ConditionPathIsMountPoint = "/mnt/storage";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "ensure-library-services-storage-layout" ''
          set -eu
          ${pkgs.coreutils}/bin/install -d -m 0750 -o damajha -g users \
            ${lib.escapeShellArg pilotRoot} \
            ${lib.escapeShellArg "${pilotRoot}/ebooks"} \
            ${lib.escapeShellArg "${pilotRoot}/audiobooks"} \
            ${lib.escapeShellArg "${pilotRoot}/downloads"} \
            ${lib.escapeShellArg "${pilotRoot}/bookdrop"}
        '';
      };
    };

    library-services-secrets = {
      description = "Provision private credentials for the reading-services pilot";
      wantedBy = [ "multi-user.target" ];
      before = [ "podman-grimmory-db.service" "podman-grimmory.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = ensureGrimmorySecrets;
      };
    };

    podman-network-library-services = {
      description = "Create the private Grimmory database container network";
      wantedBy = [ "multi-user.target" ];
      before = [ "podman-grimmory-db.service" "podman-grimmory.service" ];
      after = [ "podman.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "ensure-library-services-network" ''
          set -eu
          if ! ${pkgs.podman}/bin/podman network exists library-services; then
            ${pkgs.podman}/bin/podman network create library-services >/dev/null
          fi
        '';
      };
    };

    podman-grimmory-db = {
      requires = [ "mnt-storage.mount" "library-services-storage-layout.service" "library-services-secrets.service" "podman-network-library-services.service" ];
      after = [ "mnt-storage.mount" "library-services-storage-layout.service" "network-online.target" "tailscaled.service" "library-services-secrets.service" "podman-network-library-services.service" ];
      wants = [ "network-online.target" "tailscaled.service" ];
    };
    podman-grimmory = {
      requires = [ "mnt-storage.mount" "library-services-storage-layout.service" "library-services-secrets.service" "podman-network-library-services.service" "grimmory-db-ready.service" ];
      after = [ "mnt-storage.mount" "library-services-storage-layout.service" "network-online.target" "tailscaled.service" "library-services-secrets.service" "podman-network-library-services.service" "grimmory-db-ready.service" ];
      wants = [ "network-online.target" "tailscaled.service" ];
    };

    grimmory-db-ready = {
      description = "Wait for the Grimmory MariaDB service to accept connections";
      requires = [ "podman-grimmory-db.service" ];
      after = [ "podman-grimmory-db.service" ];
      before = [ "podman-grimmory.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "wait-for-grimmory-db" ''
          set -eu
          attempt=0
          while [ "$attempt" -lt 60 ]; do
            if ${pkgs.podman}/bin/podman healthcheck run grimmory-db >/dev/null 2>&1; then
              exit 0
            fi
            attempt=$((attempt + 1))
            ${pkgs.coreutils}/bin/sleep 2
          done
          exit 1
        '';
      };
    };
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    5000
    6060
    8788
    13378
  ];
}
