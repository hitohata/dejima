# apply the nix setting
# NIX_HOME_TARGET can be set to override the default target
# e.g., export NIX_HOME_TARGET="root@aarch64"
apply() {
  # stage all changes
  git add . 2>/dev/null

  # execute
  echo "rebuild and switch to new nix os setting..."
  sudo nixos-rebuild switch --flake ".#dejima"
}
