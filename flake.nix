{
  description = "Minimal flake wrapping my existing configuration.nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"; # or "nixos-unstable"
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };
  
  outputs = { self, nixpkgs, home-manager, ... }@inputs:
    
    let
      system = "x86_64-linux"; # change if needed: aarch64-linux on ARM
      lib = nixpkgs.lib;
      readToml = path: lib.importTOML path;
      # --- userInfo auto-discovery ---
      userInfoPath = user: builtins.toPath (./. + "/users/${user}/userInfo.toml");
      hasUserInfo  = user: builtins.pathExists (userInfoPath user);
      userDirs     = builtins.attrNames (builtins.readDir ./users);
      userNames    = builtins.filter hasUserInfo userDirs;
      userInfos    = lib.genAttrs userNames (u: readToml (userInfoPath u));
      # machine/user linkage
      systemInfo   = readToml ./hosts/optiplex/systemInfo.toml;
      mainUser     = systemInfo.mainUser;
      userInfo     = userInfos.${mainUser} or {};

    in {
      nixosConfigurations.optiplex = nixpkgs.lib.nixosSystem {
        inherit system;

        specialArgs = {
         # inherit inputs;
         # systemInfo = readToml ./hosts/optiplex/systemInfo.toml;
         inherit inputs systemInfo userInfos userInfo;
        };
        
        modules = [
          ./hosts/optiplex/configuration.nix
        ];
      };
    };
  
}
