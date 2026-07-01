# modules/systemLevel/virtualization-tools/default.nix
{
  pkgs,
  systemInfo,
  ...
}: {
  virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  # Docker Compose v2 and buildx for running upstream compose examples such as Newt.
  environment.systemPackages = with pkgs; [
    docker-compose
    docker-buildx
  ];

  # Let the primary operator run docker/compose without sudo after re-login.
  users.users."${systemInfo.mainUser}".extraGroups = ["docker"];
}
