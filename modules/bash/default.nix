{ pkgs, configName, ... }:
let
  # Import shell scripts
  initScript = builtins.readFile ./scripts/init.sh;
  functionsScript = builtins.readFile ./scripts/functions.sh;
  profileScript = builtins.readFile ./scripts/profile.sh;
  apply = builtins.readFile ./scripts/apply.sh;
in
{
  imports = [
    ./tools/starship.nix
    ./tools/fzf.nix
  ];

  # Bash completion package
  home.packages = with pkgs; [
    bash-completion
  ];

  programs.bash = {
    enable = true;
    enableCompletion = true;

    # Shell aliases
    shellAliases = {
      # Navigation
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";

      # List files
      ll = "ls -la";
      la = "ls -A";
      l = "ls -CF";

      # Safety
      rm = "rm -i";
      cp = "cp -i";
      mv = "mv -i";

      # Git shortcuts
      g = "git";
      gits = "git status";
      gat = "git add";
      gcomet = "git commit -m";
      gutpr = "git push origin HEAD && gh pr create -w";
      gut = "git push";
      gl = "git pull";
      gd = "git diff";
      gco = "git checkout";
      gb = "git branch";
      glog = "git log --oneline --graph --decorate";
      gitl = "git log --oneline --graph --decorate --color --all";

      ## github
      ghprc = "gh pr create -w";
      gopen= "gh repo view -w";

      # LazyGit
      lg = "lazygit";

      # Neovim
      v = "nvim";
      vi = "nvim";
      vim = "nvim";
    };

    # Environment variables
    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };

    # Extra content for .bashrc
    initExtra = ''
      # Set NIX_HOME_TARGET for apply command
      export NIX_HOME_TARGET="${configName}"

      ${initScript}
      ${functionsScript}
      ${apply}
    '';

    # Extra content for .profile (login shell)
    profileExtra = profileScript;
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
