{ pkgs, pkgs-unstable, ... }:
let
  luaConfig = builtins.readFile ./lua/init.lua;

  # Plugins
  corePlugins = import ./plugins/core.nix { inherit pkgs; };
  uiPlugins = import ./plugins/ui.nix { inherit pkgs; };
  completionPlugins = import ./plugins/completion.nix { inherit pkgs; };
  languagePlugins = import ./plugins/languages.nix { inherit pkgs; };

  # Packages
  nixPackages = import ./packages/nix.nix { inherit pkgs; };
  rustPackages = import ./packages/rust.nix { inherit pkgs; };
  typescriptPackages = import ./packages/typescript.nix { inherit pkgs; };
  pythonPackages = import ./packages/python.nix { inherit pkgs; };
  luaPackages = import ./packages/lua.nix { inherit pkgs; };
  toolsPackages = import ./packages/tools.nix { inherit pkgs; };
in
{
  programs.neovim = {
    enable = true;    
    defaultEditor = true;
    
    plugins = corePlugins
      ++ uiPlugins
      ++ completionPlugins
      ++ languagePlugins;

    extraLuaConfig = luaConfig;

    extraPackages = nixPackages
      ++ rustPackages
      ++ typescriptPackages
      ++ pythonPackages
      ++ luaPackages
      ++ toolsPackages;
  };
}
