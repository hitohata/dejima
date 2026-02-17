{ pkgs, ... }: with pkgs; [
  ripgrep
  fd
  lazygit

  # Clipboard support
  xclip
  xsel
  wl-clipboard  # For Wayland

  # Node.js (required for Copilot)
  nodejs

  # Spell checker
  cspell
]
