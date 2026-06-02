# modules/systemLevel/network-tools/default.nix
{
  pkgs,
  systemInfo,
  ...
}: {
  programs.wireshark = {
    enable = true;
    dumpcap.enable = true;
  };

  users.users.${systemInfo.mainUser}.extraGroups = ["wireshark"];

  environment.systemPackages = with pkgs; [
    avahi
    arp-scan
    nmap
    bind
    traceroute
    mtr
    tcpdump
    iftop
    nethogs
    tshark
    netcat
  ];
}
