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

## Safety rules

- Keep local keyboard/monitor access to the new gateway throughout the work.
- Do not use `nixos-rebuild switch` for the first network change. Build it,
  install it as the next boot generation, and reboot from the local console.
- Keep `enp3s0` disconnected from the production LAN until the old gateway has
  stopped using `192.168.10.1`.
- The current configuration does **not** provide DHCP on the trusted LAN or IoT
  LAN. Use a manually configured test client during isolated testing. Do not
  perform the production cutover until a native NixOS DHCP configuration and
  reservations have been agreed on, built, and tested.
- A failed Nix build does not activate any network changes.

## Secrets required before activation

Edit `secrets/secrets.yaml` with SOPS and set:

- `tailscale_key`: a new one-time, non-ephemeral Tailscale auth key.
- `cloudflare_dns_api_token`: the token scoped to `dejima.men` with Zone Read
  and DNS Edit permissions.

Never commit either plaintext value. The new gateway SSH host key is already
listed as a SOPS age recipient.

## Build and stage the new gateway

Run these commands from a local console on the new gateway. At this stage,
leave `enp3s0` and `enp4s0` physically disconnected.

1. Check out the migration branch and confirm that there are no unexpected
   local changes:

   ```bash
   cd ~/Projects/dejima
   git switch v2
   git pull --ff-only
   git status --short --branch
   ```

2. Build without activating anything:

   ```bash
   nix --extra-experimental-features 'nix-command flakes' \
     build --no-link \
     '.#nixosConfigurations.dejima.config.system.build.toplevel'
   ```

3. Prepare the persistent AdGuard state as described in the next section.
   Do this before booting the new configuration so the container never starts
   with the old DHCP configuration.

4. Install the configuration for the **next boot**, without switching the
   running network:

   ```bash
   sudo nixos-rebuild boot --flake '.#dejima'
   ```

5. Confirm once more that the production LAN cable is not connected to
   `enp3s0`, then reboot from the local console:

   ```bash
   sudo reboot
   ```

If the new generation does not boot or the console network checks fail, select
the previous NixOS generation in the systemd-boot menu. Do not connect the
production LAN.

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

On the new gateway, create the state directories and copy the backup while the
old gateway is reachable at `192.168.20.1`:

```bash
sudo install -d -m 0750 /var/lib/adguardhome
sudo install -d -m 0750 /var/lib/adguardhome/conf
sudo install -d -m 0750 /var/lib/adguardhome/work
scp dejima@192.168.20.1:AdGuardHome.yaml.backup /tmp/AdGuardHome.yaml
sudo install -m 0600 /tmp/AdGuardHome.yaml \
  /var/lib/adguardhome/conf/AdGuardHome.yaml
sudoedit /var/lib/adguardhome/conf/AdGuardHome.yaml
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

## Verify the temporary WAN

The old gateway must first be using Wi-Fi for Internet access and
`192.168.20.1/24` on the Ethernet link to the new gateway. Connect that Ethernet
link only to new gateway `enp2s0`. After booting the staged configuration, run
on the new gateway:

```bash
ip -brief address show enp2s0
ip route
ping -c 3 192.168.20.1
curl --fail --head https://github.com/
```

The expected new-gateway state is:

```text
enp2s0: 192.168.20.2/24
default via 192.168.20.1 dev enp2s0
```

Then inspect the services without changing them:

```bash
systemctl --no-pager --full status docker
systemctl --no-pager --full status docker-tailscale.service
systemctl --no-pager --full status docker-adguardhome.service
systemctl --no-pager --full status nginx
docker ps
sudo ss -lntup
```

AdGuard should own TCP and UDP port 53 only on `192.168.10.1` and
`192.168.50.1`. Its administration port should listen only on
`127.0.0.1:3000`.

## Test the trusted LAN in isolation

Connect one test computer directly to `enp3s0`; do not connect the production
switch. Manually configure the test computer with:

```text
Address: 192.168.10.2/24
Gateway: 192.168.10.1
DNS:     192.168.10.1
```

From that computer, test the gateway, SSH, DNS, and routed Internet access:

```bash
ping -c 3 192.168.10.1
ssh dejima@192.168.10.1
dig @192.168.10.1 dns.dejima.men
curl --fail --head https://github.com/
```

Use the SSH tunnel documented above to finish the AdGuard setup. Confirm that
the `*.dejima.men` rewrite returns `192.168.10.1` before testing Nginx. A 502
response from an individual service is expected if Kubernetes Traefik or that
service is unavailable; it still proves DNS, TLS, and Nginx were reached.

Stop here. The isolated tests do not make the gateway ready for production
clients because DHCP remains intentionally unconfigured.

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

After approving the new `192.168.10.1/32` route, test from a device that is off
the home LAN:

```bash
ping 192.168.10.1
ssh dejima@192.168.10.1
curl --resolve dns.dejima.men:443:192.168.10.1 \
  https://dns.dejima.men/
```

## Cutover and rollback

1. Keep new `enp3s0` physically disconnected.
2. Change the old gateway Ethernet to `192.168.20.1/24` while retaining Wi-Fi
   Internet access.
3. Connect old gateway Ethernet to new `enp2s0` and complete the temporary WAN
   checks above.
4. Complete the isolated client tests on `enp3s0`.
5. Add and test native NixOS DHCP with a non-overlapping dynamic pool and the
   required static reservations. This is a hard prerequisite for cutover.
6. Back up the final old AdGuard state and confirm the migrated container has
   the required rewrites, filters, allowed clients, and administrator account.
7. Withdraw the old Tailscale subnet route and approve the new `/32` route.
8. Shut down or physically disconnect the old gateway's former trusted-LAN
   connection. Confirm it no longer owns `192.168.10.1`.
9. Connect the production LAN switch to new gateway `enp3s0`.
10. Test an existing static client first, then renew one DHCP client and verify
    its address, gateway, DNS resolution, and Internet access.

To roll back, first disconnect new `enp3s0`, then restore the old gateway to
`192.168.10.1/24` and reconnect it to the LAN. Never connect both gateways to
the LAN while both claim `192.168.10.1`.

Rollback order is important:

1. Physically disconnect new gateway `enp3s0` from the production LAN.
2. Restore the old gateway's trusted-LAN address and DHCP service.
3. Only then reconnect the old gateway to the production LAN.
4. Verify a client receives gateway and DNS `192.168.10.1` and can reach the
   Internet.
5. Leave the new gateway LAN disconnected while diagnosing it. If necessary,
   boot its previous NixOS generation from the local systemd-boot menu.
