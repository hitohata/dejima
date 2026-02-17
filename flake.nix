{
  description = "Dejima";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, sops-nix, home-manager, ... }@inputs:
    let
      system = "x86_64-linux";
      username = "dejima";
      homeDirectory = "/home/dejima";
      configName = "dejima";

      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
    in {
      homeConfigurations.${configName} = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.${system};
        extraSpecialArgs = {
          inherit configName pkgs-unstable;
        };
        modules = [
          ./home.nix
          {
            home.username = username;
            home.homeDirectory = homeDirectory;
          }
        ];
      };
    };
}
