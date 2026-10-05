# Dejima

Nix flake for the `dejima` home-network gateway. It defines the NixOS host,
the `dejima` user's Home Manager environment, local DNS and DHCP, reverse
proxying, and the secrets needed by those services.

## What it runs

- Kea DHCP for the trusted LAN (`192.168.10.0/24`), IoT network
  (`192.168.50.0/24`), and temporary AP setup network (`192.168.60.0/24`)
- AdGuard Home for DNS, bound only to the two gateway LAN addresses
- Tailscale, with state persisted on the host
- Nginx with Cloudflare DNS-01 ACME certificates for `dejima.men` and its
  wildcard subdomain
- Home Manager configuration for the `dejima` account

The trusted LAN is `enp3s0` (`192.168.10.1/24`), the IoT network is `enp4s0`
(`192.168.50.1/24`). The WAN interface is `enp2s0`, using upstream DHCP.
For temporary AP setup, `enp5s0` provides an untagged network with gateway
`192.168.60.1/24`, DHCP addresses `192.168.60.2`–`192.168.60.254` (253 leases), and public
DNS servers `1.1.1.1` and `8.8.8.8`. Internet access is NATed through `enp2s0`.
Trusted LAN clients can initiate connections to the AP for management; AP setup
clients cannot initiate connections to the trusted or IoT networks.
SSID/VLAN separation is deferred. This replaces the temporary WAN bridge so
Dejima's DHCP server does not serve the upstream network. Ensure the upstream
network does not also use `192.168.60.0/24`.

Keep the AP's uplink and management traffic untagged during setup and disable
its DHCP server when using AP/bridge mode. Configure the AP's management address
via DHCP and find its lease in `/var/lib/kea/dhcp4.leases` on Dejima.
Moving WAN DHCP from the previous bridge back to `enp2s0` may change Dejima's
upstream address and interrupt connections; activate from a local console or
the trusted LAN. Reconnect or renew the AP's DHCP lease after activation.

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

AdGuard Home serves DNS on `192.168.10.1:53` and `192.168.50.1:53`; its
administration interface is host-local on `127.0.0.1:3000` and is published by
Nginx at `https://dns.dejima.men`. Nginx proxies the remaining configured
`*.dejima.men` services to the LAN and Kubernetes endpoints.

Kea's dynamic pools are `192.168.10.150`–`192.168.10.250` for the trusted LAN
and `192.168.50.10`–`192.168.50.254` for IoT. Static infrastructure addresses
are kept outside those ranges.

## Updating dependencies

Review and update flake inputs deliberately:

```bash
nix flake update
nix flake check
git diff -- flake.lock
```

Then build the NixOS configuration before activating it. Commit `flake.lock`
with the corresponding configuration change.
