# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:
let
  ETH = "end0";
  WAN = "wlan0";
  IP = "192.168.10.1"; # This PC's address
in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the extlinux boot loader. (NixOS wants to enable GRUB by default)
  boot.loader.grub.enable = false;
  # Enables the generation of /boot/extlinux/extlinux.conf
  boot.loader.generic-extlinux-compatible.enable = true;

  # Define a user account.
  users.users.dejima = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "docker" ];
    initialPassword = "init";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPecawIGB5QnbVGj1g0My61YdryyuAVysqu2r87tND1J m3"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMfs/QSBONsbnd4or8AcQobj8Rq6w6L57Sh2x63N08ii hirohatatro@gmail.com"
    ];
  };
  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    initialPassword = "nixos";
  };

  # Enable the OpenSSH daemon.
  services.openssh= {
    enable = true;
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

  # allow IP relay
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.disable_ipv6" = 1;
    "net.ipv6.conf.default.disable_ipv6" = 1;
  };

  # -- Network setting --
  networking = {
    hostName = "dejima";

    networkmanager.enable = true;
    # remove the internal network interface from the network manager
    networkmanager.unmanaged = [ "${ETH}" ];

    usePredictableInterfaceNames = true;

    nat = {
      enable = true;
      externalInterface = WAN;
      internalInterfaces = [ ETH ];
    };

    # this pc
    interfaces = {
      "${ETH}".ipv4.addresses = [{
        address = IP;
        prefixLength = 24;
      }];
    };

    firewall = {
      enable = true;
      trustedInterfaces = [ ETH ];
      extraCommands = ''
        iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
      '';
    };
  };

  # -- Pi-hole --
  services.dnsmasq.enable = false;

  virtualisation.docker.enable = true;
  
  virtualisation.oci-containers.backend = "docker";
  virtualisation.oci-containers.containers.pihole = {
    image = "pihole/pihole:latest";
    extraOptions = [ "--network=host" "--cap-add=NET_ADMIN" ];
    environment = {
      FTLCONG_webserver_api_password = "admin";
      FTLCONG_webserver_port = "80";
      FTLCONG_dns_listeningMode = "all";
      FTLCONG_dhcp_router = IP;
    };
    volumes = [
      "/var/lib/pihole/:/etc/pihole/"
      "/var/lib/dnsmasq.d/:/etc/dnsmasq.d/"
    ];
  };

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}

