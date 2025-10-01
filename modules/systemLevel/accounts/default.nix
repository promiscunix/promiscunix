# modules/systemLevel/accounts/default.nix
{ lib, pkgs, inputs, systemInfo, userInfos, ... }:

let
  acc           = systemInfo.accounts or {};
  includeRoles  = acc.includeRoles or [];     # e.g., ["workstation"] or ["*"] for all
  extraUsers    = acc.extraUsers   or [];     # always add
  exclude       = acc.exclude      or [];     # remove even if matched
  wheelRole     = acc.wheelRole    or "admin";
  mainUser      = systemInfo.mainUser;

  allUsers = builtins.attrNames userInfos;

  # match if any role is included (or wildcard)
  hasAnyIncludedRole = u:
    let rs = userInfos.${u}.roles or [];
    in (includeRoles == ["*"]) || lib.any (r: lib.elem r includeRoles) rs;

  byRoles  = builtins.filter hasAnyIncludedRole allUsers;
  base     = lib.unique (byRoles ++ extraUsers ++ [ mainUser ]);
  present  = builtins.filter (u: builtins.hasAttr u userInfos) base;
  names    = lib.subtractLists exclude present;

  # per-user shell + enable the shell if any selected user needs it
  userShellName = u: (userInfos.${u}.shell or "zsh");
  shellsUsed    = builtins.map userShellName names;
  shellFor      = u: pkgs.${userShellName u};

  # wheel if mainUser, has admin=true, or carries the wheelRole
  isWheel = u:
    let rs = userInfos.${u}.roles or [];
        adminFlag = userInfos.${u}.admin or false;
    in (u == mainUser) || adminFlag || lib.elem wheelRole rs;

  # optional: grant extra groups by role (host-side knob)
  extraGroupsByRole = acc.extraGroupsByRole or {};  # { role = [ "docker" "lp" ]; ... }
  roleGroups = u:
    let rs = userInfos.${u}.roles or [];
    in lib.unique (lib.concatMap (r: (extraGroupsByRole.${r} or [])) rs);

  groupsFor = u:
    [ "networkmanager" ]
    ++ roleGroups u
    ++ lib.optionals (isWheel u) [ "wheel" ];
in
{
  # Enable shells *only if* requested by selected users
  programs.zsh.enable  = lib.mkDefault (lib.elem "zsh"  shellsUsed);
  programs.fish.enable = lib.mkDefault (lib.elem "fish" shellsUsed);

  # ---- System users (selected by roles) ----
  users.users = lib.genAttrs names (u: {
    isNormalUser = true;
    description  = userInfos.${u}.fullName or u;
    shell        = shellFor u;
    extraGroups  = groupsFor u;
  });

  # ---- Home Manager (minimal) for selected users ----
  home-manager.useGlobalPkgs   = lib.mkDefault true;
  home-manager.useUserPackages = lib.mkDefault true;
  home-manager.extraSpecialArgs = { inherit inputs systemInfo userInfos; };

 # Per-user HM submodule: pass that user's userInfo as a module arg
  home-manager.users = lib.genAttrs names (u: {
    _module.args = { userInfo = userInfos.${u}; };
    imports      = [ (inputs.self + "/users/${u}/home.nix") ];
  });
}
