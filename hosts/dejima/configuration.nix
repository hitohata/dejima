{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./networking.nix
    ./containers.nix
    ./nginx.nix
    ./sops/default.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "dejima";

  time.timeZone = "America/Vancouver";
  i18n.defaultLocale = "en_CA.UTF-8";
  services.xserver.xkb.layout = "us";

  users.users.dejima = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPecawIGB5QnbVGj1g0My61YdryyuAVysqu2r87tND1J m3"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMIrxRnkBpffDfzvAiNkkpRA3jIMfEiZQmAJW9WoCjwV node"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHnWdJHymT9hNTFWMPTqMS9yI/c/xhDS0K8DBoAlItRM n100"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINEzr66JjoWf5GhDxiaPWx7wz113IgZFQTIt9jtllRvW x1"
    ];
  };

  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
    extraConfig = ''
      ClientAliveInterval 30
      ClientAliveCountMax 3
    '';
  };

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  environment.systemPackages = with pkgs; [
    curl
    ethtool
    tcpdump
  ];

  # Keep this at the release used for the initial installation of this PC.
  system.stateVersion = "26.05";
}
