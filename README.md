# Dejima

Nix flake for the `dejima` home-network gateway. It defines the NixOS host,
the `dejima` user's Home Manager environment, local DNS and DHCP, reverse
proxying, and the secrets needed by those services.

## What it runs

- Kea DHCP for the trusted LAN (`192.168.10.0/24`), IoT network
  (`192.168.50.0/24`), native Wi-Fi/AP management (`192.168.60.0/24`),
  and guest Wi-Fi (`192.168.100.0/24`)
- AdGuard Home for DNS on the trusted LAN, IoT, and native Wi-Fi gateway addresses
- Tailscale, with state persisted on the host
- Nginx with Cloudflare DNS-01 ACME certificates for `dejima.men` and its
  wildcard subdomain
- Home Manager configuration for the `dejima` account

The WAN interface is `enp2s0`, using upstream DHCP. The NETGEAR WAX610 connects
to `enp5s0`, carrying native VLAN 1 untagged and VLANs 10, 30, and 100 tagged.

| SSID | AP VLAN | Dejima interface / wired port | Gateway | DHCP DNS |
| --- | --- | --- | --- | --- |
| IAmDempa | 1 (untagged) | `enp5s0` | `192.168.60.1/24` | AdGuard at `192.168.60.1` |
| ToThings | 30 | `br-iot`: `vlan30` + `enp4s0` | `192.168.50.1/24` | AdGuard at `192.168.50.1` |
| DoNotUseThisWifi | 10 | `br-lan`: `vlan10` + `enp3s0` | `192.168.10.1/24` | AdGuard at `192.168.10.1` |
| GuestDenpa | 100 | `vlan100` | `192.168.100.1/24` | `1.1.1.1`, `8.8.8.8` |

Gateway addresses for trusted and IoT clients belong to the bridges, not their
physical member ports. Wired clients still use untagged Ethernet and retain
their existing subnets and DHCP pools. VLAN numbers need not match subnet numbers.
All four networks use NAT through `enp2s0` for Internet access.

IAmDempa and GuestDenpa cannot initiate direct connections to other local networks
or Docker-published services, except that IAmDempa can query AdGuard's published
DNS endpoint at `192.168.60.1:53` over TCP/UDP. GuestDenpa uses public DNS.
IAmDempa may access Dejima's Nginx on TCP ports 80/443; Nginx connects to the
private backends on its behalf. This exposes all configured Nginx virtual hosts,
including administration sites, subject to each application's authentication.
GuestDenpa cannot access Nginx. AdGuard resolves `*.dejima.men` to `192.168.60.1`
using the managed local rewrite; existing explicit host rewrites take precedence.
For a DNS-independent check from IAmDempa, use
`curl --resolve homepage.dejima.men:443:192.168.60.1 https://homepage.dejima.men/`.
Trusted clients may initiate connections to IoT and the native Wi-Fi network
to manage the AP; replies are allowed. IoT cannot initiate trusted-LAN connections.
Devices within the same bridged subnet can communicate directly.

Keep the WAX610 in AP mode with its DHCP server disabled, DHCP client enabled,
**Untagged VLAN 1**, and **Management VLAN 1** under Management > Configuration >
IP > LAN. These fields are described in the
[WAX610 manual](https://www.downloads.netgear.com/files/GDC/WAX610/WAX610_UM_EN.pdf).
The AP stays on `192.168.60.0/24`; its current DHCP address is `192.168.60.100`
but is not reserved. Find its lease in `/var/lib/kea/dhcp4.leases`.
IAmDempa clients share the AP management network, so Dejima cannot filter their
direct access to the AP. Client-to-client isolation within a Wi-Fi network must
be configured on the AP if desired.

Activate the VLAN migration from a local console: moving the trusted/IoT gateway
addresses to bridges can interrupt LAN SSH. Build first, then use
`sudo nixos-rebuild test --flake '.#dejima'` and check the network before making
it the boot default with `sudo nixos-rebuild switch --flake '.#dejima'`.
The `test` activation does not automatically roll back; a reboot returns to the
previous boot configuration until `switch` is run. Renew Wi-Fi client DHCP leases.

After activation, check `ip -br address`, `ip -4 route`, `bridge link`,
`networkctl status enp5s0 br-lan br-iot vlan100`, and `sudo nft list ruleset`.
Only `enp2s0` should supply the default route. Check each SSID's address, DNS,
and Internet access, plus trusted-Wi-Fi access to wired trusted devices and IoT
Wi-Fi access to wired IoT devices. From IAmDempa and GuestDenpa, verify connections
to a known listening service on a trusted device fail. From GuestDenpa,
`nslookup example.com 1.1.1.1` should work, while querying AdGuard at
`192.168.10.1` should fail.

## Repository layout

```text
flake.nix                  Flake inputs and the dejima NixOS configuration
hosts/dejima/              Host, networking, containers, Nginx, and SOPS modules
modules/                   Home Manager packages, Bash, and Neovim modules
home.nix                   Home Manager entry point for the dejima user
secrets/secrets.yaml       SOPS-encrypted service secrets
```

## Prerequisites

Run the commands below on the gateway as a user with `sudo` access. Nix must
have flakes enabled (the resulting system configuration enables
`nix-command` and `flakes`). To edit the encrypted secrets, use SOPS with an
Age identity that is a recipient of `secrets/secrets.yaml`.

Before the first activation, populate these SOPS keys:

- `tailscale_key` — a new, one-time, non-ephemeral Tailscale auth key
- `cloudflare_dns_api_token` — Cloudflare token with Zone Read and DNS Edit
  access for `dejima.men`

Never commit plaintext credentials. The configuration reads the secrets at
activation time and writes restricted files for the services that need them.

## Build and apply

Clone the repository and inspect the configuration first:

```bash
git clone <repository-url> ~/Projects/dejima
cd ~/Projects/dejima
nix --extra-experimental-features 'nix-command flakes' \
  build --no-link '.#nixosConfigurations.dejima.config.system.build.toplevel'
```

For routine, already-tested changes, activate the flake with:

```bash
sudo nixos-rebuild switch --flake '.#dejima'
```

The shell environment also provides an `apply` helper. It runs `git add .`
before the same rebuild, so review the working tree before using it.

## Operations

Useful checks after an activation:

```bash
systemctl --no-pager --full status kea-dhcp4-server nginx
systemctl --no-pager --full status docker-adguardhome.service docker-tailscale.service
docker ps
ip -brief address
```

AdGuard Home serves DNS on `192.168.10.1:53`, `192.168.50.1:53`, and
`192.168.60.1:53`; its
administration interface is host-local on `127.0.0.1:3000` and is published by
Nginx at `https://dns.dejima.men`. Nginx proxies the remaining configured
`*.dejima.men` services to the LAN and Kubernetes endpoints.

The media request portal (Seerr) is proxied through Traefik at
`https://jellyseerr.dejima.men`, using the shared wildcard certificate. Its DNS
record must resolve to the gateway. Sonarr, Radarr, and Bazarr remain available
through their `*.n100.lan` Kubernetes ingress hosts without gateway proxy routes.

### Local service DNS

Kea advertises only `192.168.60.1` as DNS for native Wi-Fi clients. Public DNS
servers belong in AdGuard's upstream settings, not as a secondary DHCP DNS
server: clients using a public resolver cannot resolve these local names.
Guest Wi-Fi retains public DNS and isolation. The WAX610 SSID/VLAN settings
and Nginx configuration do not need to change for this DNS migration.

Before each AdGuard container start, `hosts/dejima/adguard-local-dns.py` merges
the managed `*.dejima.men -> 192.168.60.1` rewrite into the persistent
`/var/lib/adguardhome/conf/AdGuardHome.yaml`. It runs after the old container
has been removed, preserves other settings and explicit rewrites, and saves
the first original as `AdGuardHome.yaml.before-local-dns`. The configuration
must already exist; on a fresh gateway, restore AdGuard's configuration and
work directories from backup before starting it. Back these directories up
securely; credentials stay outside Git. Edit the script to change the managed
wildcard, since changes to that wildcard in the UI are reset on container start.

Build and activate the gateway configuration using the commands above. This
restarts AdGuard briefly. Reconnect Wi-Fi clients to renew DHCP, then check
from a device on IAmDempa:

```bash
nslookup jellyfin.dejima.men 192.168.60.1
nslookup homepage.dejima.men 192.168.60.1
nslookup example.com 192.168.60.1
curl https://jellyfin.dejima.men/System/Info/Public
```

Check TCP DNS too with `dig +tcp @192.168.60.1 jellyfin.dejima.men` if available.
Both local names should resolve to the gateway (an existing explicit rewrite
may return `192.168.10.1`). Verify GuestDenpa still cannot query any of the
gateway's DNS addresses or reach Nginx. Devices with manually configured DNS
or encrypted DNS must use the local resolver to resolve these names.

Rolling back Nix does not undo the persistent rewrite. To restore the original
AdGuard configuration, first roll back the Nix change, then stop
`docker-adguardhome`, restore `AdGuardHome.yaml.before-local-dns` with its
ownership and permissions, and start the service. Renew client DHCP again.

Kea's dynamic pools are `192.168.10.150`–`192.168.10.250` for the trusted LAN
and `192.168.50.10`–`192.168.50.254` for IoT. Static infrastructure addresses
are kept outside those ranges. Native Wi-Fi uses `192.168.60.2`–`192.168.60.254`
and guest Wi-Fi uses `192.168.100.2`–`192.168.100.254` (253 leases each).

## Updating dependencies

Review and update flake inputs deliberately:

```bash
nix flake update
nix flake check
git diff -- flake.lock
```

Then build the NixOS configuration before activating it. Commit `flake.lock`
with the corresponding configuration change.
