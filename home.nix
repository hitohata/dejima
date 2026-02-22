{ pkgs, pkgs-unstable, configName, ... }: {
  home.stateVersion = "25.11";

  # to avoid man-db conflict
  manual.manpages.enable = false;
  programs.man.enable = false;
  home.enableNixpkgsReleaseCheck = false;

  # Set NIX_HOME_TARGET so 'apply' command knows which config to use
  home.sessionVariables = {
    NIX_HOME_TARGET = configName;
    SOPS_AGE_SSH_PRIVATE_KEY_FILE = "/etc/ssh/ssh_host_ed25519_key";
  };

  # Module imports
  imports = [
    ./modules/nvim/default.nix
    ./modules/bash/default.nix
    ./modules/packages/default.nix
  ];
}
