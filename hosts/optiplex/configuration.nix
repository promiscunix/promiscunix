{ config, lib, pkgs, inputs, systemInfo, userInfo, userInfos, ... }:

# let
#   acc     = systemInfo.accounts or {};
#   all     = builtins.attrNames userInfos;
#   base    = if (acc.mode or "allowlist") == "all"
#             then all
#             else lib.unique ((acc.allow or []) ++ [ systemInfo.mainUser ]);
#   names   = lib.subtractLists (acc.exclude or []) (builtins.filter (u: builtins.hasAttr u userInfos) base);
  
# in
 {
  imports =
    [ 
      ./hardware-configuration.nix
      ../../modules/core/default.nix
      ../../modules/systemLevel/accounts
      inputs.home-manager.nixosModules.home-manager
    ];

  # System users for this host
  # users.users = lib.genAttrs names (u: {
  #   isNormalUser = true;
  #   description  = userInfos.${u}.fullName or u;
  #   shell        = pkgs.${(userInfos.${u}.shell or "zsh")};
  #   extraGroups  = [ "networkmanager" ] ++ lib.optionals (u == systemInfo.mainUser) [ "wheel" ];
  # });
  
  # home-manager.useGlobalPkgs = true;
  # home-manager.useUserPackages = true;
  # home-manager.extraSpecialArgs = { inherit inputs systemInfo userInfo userInfos; };
  # home-manager.users = lib.genAttrs names (u: import ../../users/${u}/home.nix);

  environment.systemPackages = [
    inputs.home-manager.packages.${pkgs.system}.home-manager
  ];

  system.stateVersion = "25.05"; # Did you read the comment?
}

