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
    "net.ipv6.conf.all.forwarding" = 1;
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
      trustedInterfaces = [ ETH "tailscale0" ];
      # allow the Tailscale UDP port through the firewall
      allowedUDPPorts = [ config.services.tailscale.port ];
        # let you SSH in over the public internet
      allowedTCPPorts = [ 22 ];
      # for pi-hole
      extraCommands = ''
        iptables -t mangle -a forward -p tcp --tcp-flags syn,rst syn -j tcpmss --clamp-mss-to-pmtu
      '';
    };
  };

  # -- pi-hole --
  services.dnsmasq.enable = false;

  virtualisation.docker.enable = true;
  
  virtualisation.oci-containers.backend = "docker";
  virtualisation.oci-containers.containers.pihole = {
    image = "pihole/pihole:latest";
    extraOptions = [
      "--network=host"
      "--cap-add=net_admin"
      "--env-file=${config.sops.secrets.pihole_password.path}"
    ];
    environment = {
      ftlconf_webserver_port = "80";
      ftlconf_dns_listeningmode = "all";
      ftlconf_dhcp_router = IP;
    };
    volumes = [
      "/var/lib/pihole/:/etc/pihole/"
      "/var/lib/dnsmasq.d/:/etc/dnsmasq.d/"
    ];
  };

  # -- tailscal --
  services.tailscale = {
    enable = true;
  };
  environment.systemPackages = [ pkgs.tailscale ];

  # create a oneshot job to authenticate to Tailscale
  systemd.services.tailscale-autoconnect = {
    description = "Automatic connection to Tailscale";

    # make sure tailscale is running before trying to connect to tailscale
    after = [ "network-pre.target" "tailscale.service" ];
    wants = [ "network-pre.target" "tailscale.service" ];
    wantedBy = [ "multi-user.target" ];

    # set this service as a oneshot job
    serviceConfig.Type = "oneshot";

    # have the job run this shell script
    script = with pkgs; ''
      AUTH_KEY=$(cat ${config.sops.secrets.tailscale_key.path})

      # wait for tailscaled to settle
      sleep 2

      # check if we are already authenticated to tailscale
      status="$(${tailscale}/bin/tailscale status -json | ${jq}/bin/jq -r .BackendState)"
      if [ $status = "Running" ]; then # if so, then do nothing
        exit 0
      fi

      # otherwise authenticate with tailscale
      ${tailscale}/bin/tailscale up -authkey "$AUTH_KEY"
    '';
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

