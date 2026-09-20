{ config, ... }:

{
  virtualisation.docker.enable = true;
  virtualisation.oci-containers.backend = "docker";

  sops.templates."tailscale.env" = {
    mode = "0400";
    content = ''
      TS_AUTHKEY=${config.sops.placeholder.tailscale_key}
    '';
  };

  virtualisation.oci-containers.containers = {
    tailscale = {
      image = "tailscale/tailscale:v1.102.3";
      environmentFiles = [ config.sops.templates."tailscale.env".path ];
      environment = {
        TS_AUTH_ONCE = "true";
        TS_EXTRA_ARGS = "--accept-dns=false";
        TS_HOSTNAME = "dejima-new";
        TS_ROUTES = "192.168.10.1/32";
        TS_STATE_DIR = "/var/lib/tailscale";
        TS_TAILSCALED_EXTRA_ARGS = "--netfilter-mode=off";
        TS_USERSPACE = "false";
      };
      volumes = [
        "/var/lib/tailscale-container:/var/lib/tailscale"
      ];
      extraOptions = [
        "--network=host"
        "--device=/dev/net/tun:/dev/net/tun"
        "--cap-add=NET_ADMIN"
      ];
    };

    adguardhome = {
      image = "adguard/adguardhome:v0.107.79";
      ports = [
        "192.168.10.1:53:53/tcp"
        "192.168.10.1:53:53/udp"
        "192.168.50.1:53:53/tcp"
        "192.168.50.1:53:53/udp"
        "127.0.0.1:3000:3000/tcp"
      ];
      volumes = [
        "/var/lib/adguardhome/conf:/opt/adguardhome/conf"
        "/var/lib/adguardhome/work:/opt/adguardhome/work"
      ];
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/tailscale-container 0700 root root -"
    "d /var/lib/adguardhome 0750 root root -"
    "d /var/lib/adguardhome/conf 0750 root root -"
    "d /var/lib/adguardhome/work 0750 root root -"
  ];
}
