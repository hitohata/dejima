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
      ./sops/default.nix
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
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMIrxRnkBpffDfzvAiNkkpRA3jIMfEiZQmAJW9WoCjwV node"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHnWdJHymT9hNTFWMPTqMS9yI/c/xhDS0K8DBoAlItRM n100"
    ];
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
    networkmanager.enable = false;

    usePredictableInterfaceNames = true;
    
    # Wifi
    wireless = {
      enable = true;

      secretsFile = config.sops.secrets.azure_password.path;

      networks = {
        "TELUS1196" = {
          pskRaw = "ext:azure_password"; 
        };
      };
    };

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
    extraOptions = [
      "--network=host"
      "--cap-add=NET_ADMIN"
      "--env-file=${config.sops.secrets.pihole_password.path}"
    ];
    environment = {
      FTLCONF_webserver_port = "80";
      FTLCONF_dns_listeningMode = "all";
      FTLCONF_dhcp_router = IP;
    };
    volumes = [
      "/var/lib/pihole/:/etc/pihole/"
      "/var/lib/dnsmasq.d/:/etc/dnsmasq.d/"
    ];
  };

  # Avahi
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
      domain = true;
      hinfo = true;
      userServices = true;
    };
  };

  # allow access to the ssh key
  systemd.tmpfiles.rules = [
    "z /etc/ssh/ssh_host_ed25519_key 0640 root wheel - -"
  ];

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}

