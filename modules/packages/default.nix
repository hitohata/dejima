
{ pkgs, ... }: {
  home.packages = with pkgs; [
    git

    # Core utilities
    coreutils
    curl
    usbutils

    # File tools
    tree
    file
    unzip
    zip

    # Search tools
    ripgrep
    fd
    fzf

    # File managers
    yazi

    # Process tools
    htop
    btop

    # Git tools
    lazygit
    gh

    # Network tools
    jq
    yq

    # Development tools
    gnumake
    cmake

    # dot dir
    direnv
    nix-direnv
  ];
}
