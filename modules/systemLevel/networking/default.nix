{ config, pkgs, lib, systemInfo, ... }:

{
    networking.useDHCP = false;          # don't let DHCP override
    
    networking = {
    hostName = systemInfo.hostName;
    networkmanager = {
      enable = true;  
      ensureProfiles.profiles = {
        "wired-static" = {
          connection.type = "ethernet";
          connection.id = "wired-static";
          connection.interface-name = systemInfo.networkInterfaceName;  # Make sure this matches your interface
          connection.autoconnect = true;
          connection.autoconnect-priority = 100;
            
          ipv4.method = "manual";
          ipv4.addresses = systemInfo.ipAddr;  #Desired IP address
          ipv4.gateway = "192.168.1.254";  #Routers IP address
          ipv4.dns = "1.1.1.1;8.8.8.8";
          ipv6.method = "ignore";
        };
      };
    };
  };

    systemd.services.activate-wired-static = {
    description = "Ensure NM static profile is active";
    after = [ "NetworkManager.service" ];
    wants = [ "NetworkManager.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      set -eu
      nmcli con reload || true
      # Activate wired-static if it's not already active
      if ! nmcli -t -f NAME con show --active | grep -qx wired-static; then
        nmcli con up wired-static || true
        # Optionally take down any other active ethernet profiles
        for c in $(nmcli -t -f NAME,TYPE con show --active | awk -F: '$2=="ethernet"{print $1}' | grep -v '^wired-static$'); do
          nmcli con down "$c" || true
        done
      fi
    '';
  };
}
