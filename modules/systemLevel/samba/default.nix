# Add this to your /etc/nixos/configuration.nix
{
  config,
  pkgs,
  ...
}: {
  # Enable Samba services
  services.samba = {
    enable = true;
    openFirewall = true;

    settings = {
      global = {
        workgroup = "WORKGROUP";
        "server string" = "Optiplex Server";
        security = "user";
        "map to guest" = "never";

        # Performance optimizations
        "socket options" = "TCP_NODELAY IPTOS_LOWDELAY SO_RCVBUF=131072 SO_SNDBUF=131072";
        "read raw" = "yes";
        "write raw" = "yes";

        # macOS/iOS compatibility
        "vfs objects" = "catia fruit streams_xattr";
        "fruit:metadata" = "stream";
        "fruit:model" = "MacSamba";
        "fruit:posix_rename" = "yes";
        "fruit:veto_appledouble" = "no";
        "fruit:wipe_intentionally_left_blank_rfork" = "yes";
        "fruit:delete_empty_adfiles" = "yes";
      };

      Obsidian = {
        path = "/srv/@data/@obsidian";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "valid users" = "damajha";
        "create mask" = "0644";
        "directory mask" = "0755";
        "force user" = "damajha";
        "force group" = "users";
      };

      Zotero = {
        path = "/srv/@data/@zotero";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "valid users" = "damajha";
        "create mask" = "0644";
        "directory mask" = "0755";
        "force user" = "damajha";
        "force group" = "users";
      };
    };
  };

  # Samba wsdd (Web Service Discovery) for better network discovery
  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };

  # Avahi for better network discovery (especially for macOS/iOS)
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
      domain = true;
      hinfo = true;
      userServices = true;
      workstation = true;
    };
  };

  # Snapper configuration for automatic Btrfs snapshots
  services.snapper = {
    # Enable snapper globally
    snapshotInterval = "hourly";
    cleanupInterval = "1d";

    configs = {
      obsidian = {
        SUBVOLUME = "/srv/@data/@obsidian";
        ALLOW_USERS = ["damajha"];

        # Timeline snapshots (automatic)
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;

        # Retention policy
        TIMELINE_MIN_AGE = "1800"; # Keep snapshots for at least 30 minutes
        TIMELINE_LIMIT_HOURLY = "24"; # Keep 24 hourly snapshots (1 day)
        TIMELINE_LIMIT_DAILY = "7"; # Keep 7 daily snapshots (1 week)
        TIMELINE_LIMIT_WEEKLY = "4"; # Keep 4 weekly snapshots (1 month)
        TIMELINE_LIMIT_MONTHLY = "12"; # Keep 12 monthly snapshots (1 year)
        TIMELINE_LIMIT_YEARLY = "3"; # Keep 3 yearly snapshots
      };

      zotero = {
        SUBVOLUME = "/srv/@data/@zotero";
        ALLOW_USERS = ["damajha"];

        # Timeline snapshots (automatic)
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;

        # Retention policy
        TIMELINE_MIN_AGE = "1800";
        TIMELINE_LIMIT_HOURLY = "24";
        TIMELINE_LIMIT_DAILY = "7";
        TIMELINE_LIMIT_WEEKLY = "4";
        TIMELINE_LIMIT_MONTHLY = "12";
        TIMELINE_LIMIT_YEARLY = "3";
      };
    };
  };

  # Install snapper and btrfs tools
  environment.systemPackages = with pkgs; [
    btrfs-progs
    snapper
    samba
  ];

  # Create necessary directories
  systemd.tmpfiles.rules = [
    "d /srv/data 0755 root root -"
  ];
}
