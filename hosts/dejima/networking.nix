{ ... }:

{
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 0;
  };

  # Gateway addresses must exist even when no client or switch is connected.
  # Host services such as AdGuard bind to these addresses during boot.
  systemd.network.networks = {
    "40-enp3s0".networkConfig = {
      ConfigureWithoutCarrier = true;
      IgnoreCarrierLoss = true;
    };
    "40-enp4s0".networkConfig = {
      ConfigureWithoutCarrier = true;
      IgnoreCarrierLoss = true;
    };
  };

  networking = {
    useNetworkd = true;
    useDHCP = false;
    networkmanager.enable = false;
    wireless.enable = false;

    nameservers = [ "1.1.1.1" "8.8.8.8" ];
    defaultGateway = {
      address = "192.168.20.1";
      interface = "enp2s0";
    };

    interfaces = {
      # Temporary migration WAN connected to the old gateway.
      enp2s0.ipv4.addresses = [{
        address = "192.168.20.2";
        prefixLength = 24;
      }];

      # Trusted LAN. This cable must remain disconnected until the old gateway
      # has stopped using 192.168.10.1.
      enp3s0.ipv4.addresses = [{
        address = "192.168.10.1";
        prefixLength = 24;
      }];

      # IoT network. DHCP is deliberately deferred.
      enp4s0.ipv4.addresses = [{
        address = "192.168.50.1";
        prefixLength = 24;
      }];

      # enp5s0 is intentionally left unconfigured.
    };

    nftables.enable = true;

    nat = {
      enable = true;
      externalInterface = "enp2s0";
      internalInterfaces = [ "enp3s0" "enp4s0" ];
    };

    firewall = {
      enable = true;
      backend = "nftables";
      filterForward = true;
      checkReversePath = "loose";

      interfaces = {
        enp2s0.allowedUDPPorts = [ 41641 ];

        enp3s0 = {
          allowedTCPPorts = [ 22 53 80 443 ];
          allowedUDPPorts = [ 53 ];
        };

        # IoT devices may use gateway DNS, but no other host service.
        enp4s0 = {
          allowedTCPPorts = [ 53 ];
          allowedUDPPorts = [ 53 ];
        };

        tailscale0 = {
          allowedTCPPorts = [ 22 53 80 443 ];
          allowedUDPPorts = [ 53 ];
        };
      };

      extraForwardRules = ''
        # Trusted LAN may initiate connections to IoT; IoT may not initiate
        # connections to the trusted LAN. Return traffic is statefully allowed.
        iifname "enp3s0" oifname "enp4s0" accept
      '';
    };
  };
}
