# Dejima gateway migration

## Interface and network plan

| Interface | Role | Address |
| --- | --- | --- |
| `enp2s0` | Temporary WAN to old gateway | `192.168.20.2/24`, gateway `192.168.20.1` |
| `enp3s0` | Trusted LAN | `192.168.10.1/24` |
| `enp4s0` | IoT | `192.168.50.1/24` |
| `enp5s0` | Reserved | unconfigured |

The old gateway must stop using `192.168.10.1` before `enp3s0` is connected
to the production LAN.

DHCP is deliberately deferred. The old AdGuard configuration currently leases
`192.168.10.10` through `192.168.10.255`, which overlaps static hosts `.10` and
`.100` and includes the broadcast address. Do not reproduce that pool. A safe
pool and reservations must be chosen before the old DHCP server is retired.

## Secrets required before activation

Edit `secrets/secrets.yaml` with SOPS and set:

- `tailscale_key`: a new one-time, non-ephemeral Tailscale auth key.
- `cloudflare_dns_api_token`: the token scoped to `dejima.men` with Zone Read
  and DNS Edit permissions.

Never commit either plaintext value. The new gateway SSH host key is already
listed as a SOPS age recipient.

## AdGuard state migration

The source configuration is:

```text
/var/lib/private/AdGuardHome/AdGuardHome.yaml
```

Its backup is `~/AdGuardHome.yaml.backup` on the old gateway. Before starting
the new container, copy it to:

```text
/var/lib/adguardhome/conf/AdGuardHome.yaml
```

Before starting the container, edit only the copied persistent file at
`/var/lib/adguardhome/conf/AdGuardHome.yaml` and set:

```yaml
dhcp:
  enabled: false
  interface_name: ""
```

Do not start the container with the copied `dhcp.enabled: true` and obsolete
`end0` interface. After AdGuard starts, add `192.168.50.0/24` to allowed DNS
clients through its UI and replace the old `.sv` service rewrites with:

| Name | Answer |
| --- | --- |
| `*.dejima.men` | `192.168.10.1` |

Retain the existing `*.n100.lan` rewrite to `192.168.10.10` for direct LAN
access to services that intentionally provide a LAN alias.

The existing configuration has no AdGuard UI users (`users: []`). Immediately
after the first container start, reach the loopback-bound UI through an SSH
tunnel and create an administrator account before treating the proxied UI as
ready:

```bash
ssh -L 3000:127.0.0.1:3000 dejima@192.168.10.1
```

Then open `http://127.0.0.1:3000` locally. Do not leave the administration UI
without authentication.

## Tailscale

The new container registers as `dejima-new`, persists state under
`/var/lib/tailscale-container`, and advertises only `192.168.10.1/32`.
Approve that route in the Tailscale admin console and configure tailnet DNS to
use `192.168.10.1`. Remote web access then reaches Nginx; remote SSH reaches the
gateway and uses ProxyJump for LAN hosts.

Example:

```bash
ssh -J dejima@192.168.10.1 user@192.168.10.10
```

Withdraw the old gateway's `192.168.10.0/24` route before approving the new
route.

## Cutover and rollback

1. Keep new `enp3s0` physically disconnected.
2. Change the old gateway Ethernet to `192.168.20.1/24` while retaining Wi-Fi
   Internet access.
3. Connect old gateway Ethernet to new `enp2s0` and verify Internet access.
4. Test the new gateway from an isolated client on `enp3s0`.
5. Resolve the deferred DHCP pool and reservations.
6. Confirm the old gateway no longer owns `192.168.10.1`.
7. Connect new `enp3s0` to the production LAN.

To roll back, first disconnect new `enp3s0`, then restore the old gateway to
`192.168.10.1/24` and reconnect it to the LAN. Never connect both gateways to
the LAN while both claim `192.168.10.1`.
