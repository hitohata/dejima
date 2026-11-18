{ ... }:

{
  # Routed-traffic restrictions for the dedicated bridge. Keep these addresses
  # in sync with daikin_proxy/settings.nix. The bridge has a static address
  # outside Kea's dynamic pool and does not need a DHCP reservation.
  networking.nftables.tables.daikin-bridge-guard = {
    family = "inet";
    content = ''
      chain input {
        type filter hook input priority -2; policy accept;
        ip saddr 192.168.50.3 ct state { established, related } accept
        # No new bridge connections to gateway services, including local DNS.
        ip saddr 192.168.50.3 counter drop
      }

      chain forward {
        type filter hook forward priority -2; policy accept;
        ip saddr 192.168.50.3 ct state { established, related } accept
        ip daddr 192.168.50.3 ct state { established, related } accept

        # Only these bridge-initiated connections may cross the gateway.
        ip saddr 192.168.50.3 ip daddr { 192.168.50.13, 192.168.50.16 } udp dport 3610 counter accept
        ip saddr 192.168.50.3 oifname "enp2s0" ip daddr { 162.159.200.1, 162.159.200.123 } udp dport 123 counter accept
        ip saddr 192.168.50.3 counter drop

        # Allow trusted-LAN SSH and Home Assistant's TLS MQTT connection.
        iifname "br-lan" ip saddr 192.168.10.0/24 ip daddr 192.168.50.3 tcp dport 22 counter accept
        ip saddr 192.168.50.2 ip daddr 192.168.50.3 tcp dport 8883 counter accept
        ip daddr 192.168.50.3 counter drop
      }
    '';
  };

  # These inet hooks do not isolate peers sharing the IoT VLAN. Same-subnet
  # traffic may bypass Dejima entirely. IP-based filtering also cannot stop a
  # compromised administrator from changing the bridge's source IP/MAC.
  # The Pi's own firewall/service sandbox remain necessary; a separate access
  # VLAN/port is required for a stronger network-enforced boundary.
}
