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
        interfaces = [ "br-lan" "br-iot" "enp5s0" "vlan100" ];
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
          id = 3;
          subnet = "192.168.60.0/24";
          interface = "enp5s0";
          pools = [{
            pool = "192.168.60.2 - 192.168.60.254";
          }];
          option-data = [
            {
              name = "routers";
              data = "192.168.60.1";
            }
            {
              name = "domain-name-servers";
              data = "1.1.1.1, 8.8.8.8";
            }
          ];
        }
        {
          id = 1;
          subnet = "192.168.10.0/24";
          interface = "br-lan";
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
          interface = "br-iot";
          pools = [{
            pool = "192.168.50.10 - 192.168.50.254";
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
        {
          id = 4;
          subnet = "192.168.100.0/24";
          interface = "vlan100";
          pools = [{
            pool = "192.168.100.2 - 192.168.100.254";
          }];
          option-data = [
            {
              name = "routers";
              data = "192.168.100.1";
            }
            {
              name = "domain-name-servers";
              data = "1.1.1.1, 8.8.8.8";
            }
          ];
        }
      ];
    };
  };

  # Gateway addresses must exist even when no client or switch is connected.
  # Host services such as AdGuard bind to these addresses during boot.
  systemd.network.networks = {
    "40-br-lan".networkConfig = {
      ConfigureWithoutCarrier = true;
      IgnoreCarrierLoss = true;
    };
    "40-br-iot".networkConfig = {
      ConfigureWithoutCarrier = true;
      IgnoreCarrierLoss = true;
    };
    "40-enp5s0".networkConfig = {
      ConfigureWithoutCarrier = true;
      IgnoreCarrierLoss = true;
    };
    "40-vlan100".networkConfig = {
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

    # The WAX610 sends VLAN 1 (including management) untagged. Only the other
    # SSIDs get VLAN subinterfaces; the parent enp5s0 retains 192.168.60.1.
    vlans = {
      vlan10 = { id = 10; interface = "enp5s0"; };
      vlan30 = { id = 30; interface = "enp5s0"; };
      vlan100 = { id = 100; interface = "enp5s0"; };
    };

    bridges = {
      br-lan.interfaces = [ "enp3s0" "vlan10" ];
      br-iot.interfaces = [ "enp4s0" "vlan30" ];
    };

    interfaces = {
      enp2s0.useDHCP = true;

      # IAmDempa and AP management: native/untagged VLAN 1.
      enp5s0.ipv4.addresses = [{
        address = "192.168.60.1";
        prefixLength = 24;
      }];

      # Trusted wired LAN and DoNotUseThisWifi share one subnet and DHCP pool.
      br-lan.ipv4.addresses = [{
        address = "192.168.10.1";
        prefixLength = 24;
      }];

      # Wired IoT and ToThings share one subnet and DHCP pool.
      br-iot.ipv4.addresses = [{
        address = "192.168.50.1";
        prefixLength = 24;
      }];

      # GuestDenpa uses public DNS instead of AdGuard.
      vlan100.ipv4.addresses = [{
        address = "192.168.100.1";
        prefixLength = 24;
      }];
    };

    nftables.enable = true;

    # Enforce isolation before the NixOS firewall's general DNAT allowance.
    # Otherwise Docker-published services (including AdGuard) can bypass the
    # per-interface host firewall. Replies to trusted management are permitted.
    nftables.tables.wifi-isolation = {
      family = "inet";
      content = ''
        chain forward {
          type filter hook forward priority -1; policy accept;
          iifname { "enp5s0", "vlan100" } ct state { established, related } accept
          iifname { "enp5s0", "vlan100" } oifname != "enp2s0" counter drop
        }
      '';
    };

    nat = {
      enable = true;
      externalInterface = "enp2s0";
      internalInterfaces = [ "br-lan" "br-iot" "enp5s0" "vlan100" ];
    };

    firewall = {
      enable = true;
      backend = "nftables";
      filterForward = true;
      checkReversePath = "loose";

      interfaces = {
        enp2s0.allowedUDPPorts = [ 41641 ];

        # IAmDempa may reach host Nginx, which proxies to the private backends.
        # Direct forwarding into the trusted/IoT networks remains blocked.
        enp5s0 = {
          allowedTCPPorts = [ 80 443 ];
          allowedUDPPorts = [ 67 ];
        };

        # GuestDenpa uses external DNS and only needs host DHCP access.
        vlan100.allowedUDPPorts = [ 67 ];

        br-lan = {
          allowedTCPPorts = [ 22 53 80 443 ];
          # DNS and DHCP respectively.
          allowedUDPPorts = [ 53 67 ];
        };

        # IoT devices may use gateway DNS, but no other host service.
        br-iot = {
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

        # Allow trusted clients to configure the AP by its DHCP address.
        iifname "br-lan" oifname "enp5s0" accept

        # Keep wired/Wi-Fi peers on the same LAN connected even if bridge
        # traffic is passed through IP netfilter (for example by Docker).
        iifname "br-lan" oifname "br-lan" accept
        iifname "br-iot" oifname "br-iot" accept

        # Trusted LAN may initiate connections to IoT; IoT may not initiate
        # connections to the trusted LAN. Return traffic is statefully allowed.
        iifname "br-lan" oifname "br-iot" accept
      '';
    };
  };
}
