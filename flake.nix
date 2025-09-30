{
  description = "Minimal flake wrapping my existing configuration.nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"; # or "nixos-unstable"
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };
  
  outputs = { self, nixpkgs, ... }@inputs: 
    
    let
      system = "x86_64-linux"; # change if needed: aarch64-linux on ARM
      lib = nixpkgs.lib;
      readToml = path: lib.importTOML path;
    in {
      nixosConfigurations.optiplex = nixpkgs.lib.nixosSystem {
        inherit system;

        specialArgs = {
          inherit inputs;
          systemInfo = readToml ./hosts/optiplex/systemInfo.toml;
        };
        
        modules = [
          ./hosts/optiplex/configuration.nix
        ];
      };
    };
  
}
