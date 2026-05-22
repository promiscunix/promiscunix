# flake.nix
{
  description = "A flake that auto discovers Users and installs them based on roles per host";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"; # or "nixos-unstable"
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    hermes-agent = {
      url = "github:NousResearch/hermes-agent";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    sops-nix,
    ...
  } @ inputs: let
    system = "x86_64-linux"; # change if needed: aarch64-linux on ARM
    lib = nixpkgs.lib;
    readToml = path: lib.importTOML path;

    # --- userInfo auto-discovery ---
    userInfoPath = user: builtins.toPath (./. + "/users/${user}/userInfo.toml");
    hasUserInfo = user: builtins.pathExists (userInfoPath user);
    userDirs = builtins.attrNames (builtins.readDir ./users);
    userNames = builtins.filter hasUserInfo userDirs;
    userInfos = lib.genAttrs userNames (u: readToml (userInfoPath u));

    # --- host factory ---
    mkHost = host: let
      systemInfo = readToml (builtins.toPath (./. + "/hosts/${host}/systemInfo.toml"));
      mainUser = systemInfo.mainUser;
      userInfo = userInfos.${mainUser} or {};
      repoRoot = ./.; # <- reliable base path for imports
    in
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {inherit inputs systemInfo userInfos userInfo repoRoot;};
        modules = [
          (./. + "/hosts/${host}/configuration.nix")
        ];
      };
  in {
    nixosConfigurations = {
      theLibrary = mkHost "theLibrary";
      virtnix = mkHost "virtnix";
      theBullpen = mkHost "theBullpen";
      MTAC = mkHost "MTAC";
      # add more machines here:
      # desktop = mkHost "desktop";
    };
  };
}
