{ ... }:

{
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 0;
  };

  # DHCP is a fundamental LAN service and therefore runs directly on NixOS.
  # Static infrastructure addresses stay below the dynamic pools.
  services.kea.dhcp4 = {
    enable = true;
    settings = {
      authoritative = true;
      valid-lifetime = 86400;

      interfaces-config = {
        interfaces = [ "enp3s0" "enp4s0" ];
        # A port may have no carrier while the gateway or switch boots.
        # Keep serving available ports while retrying unavailable ones for an
        # hour. If a port is connected later, restart this service once.
        service-sockets-require-all = false;
        service-sockets-max-retries = 360;
        service-sockets-retry-wait-time = 10000;
      };

      lease-database = {
        type = "memfile";
        persist = true;
        name = "/var/lib/kea/dhcp4.leases";
      };

      subnet4 = [
        {
          id = 1;
          subnet = "192.168.10.0/24";
          pools = [{
            pool = "192.168.10.150 - 192.168.10.250";
          }];
          option-data = [
            {
              name = "routers";
              data = "192.168.10.1";
            }
            {
              name = "domain-name-servers";
              data = "192.168.10.1";
            }
            {
              name = "domain-name";
              data = "lan";
            }
          ];
        }
        {
          id = 2;
          subnet = "192.168.50.0/24";
          pools = [{
            pool = "192.168.50.150 - 192.168.50.250";
          }];
          option-data = [
            {
              name = "routers";
              data = "192.168.50.1";
            }
            {
              name = "domain-name-servers";
              data = "192.168.50.1";
            }
            {
              name = "domain-name";
              data = "iot.lan";
            }
          ];
        }
      ];
    };
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

      # IoT network.
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
          # DNS and DHCP respectively.
          allowedUDPPorts = [ 53 67 ];
        };

        # IoT devices may use gateway DNS, but no other host service.
        enp4s0 = {
          allowedTCPPorts = [ 53 ];
          # DNS and DHCP respectively.
          allowedUDPPorts = [ 53 67 ];
        };

        tailscale0 = {
          allowedTCPPorts = [ 22 53 80 443 ];
          allowedUDPPorts = [ 53 ];
        };
      };

      extraForwardRules = ''
        # Dockerized services may reach the Internet through the host WAN.
        iifname "docker0" oifname "enp2s0" accept

        # Trusted LAN may initiate connections to IoT; IoT may not initiate
        # connections to the trusted LAN. Return traffic is statefully allowed.
        iifname "enp3s0" oifname "enp4s0" accept
      '';
    };
  };
}
