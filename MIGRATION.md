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

Native NixOS Kea DHCP serves only the trusted LAN and leases
`192.168.10.150` through `192.168.10.250`. It supplies gateway and DNS
`192.168.10.1`. Static infrastructure addresses such as `.10`, `.11`, and
`.100` remain outside the pool. The IoT network does not yet provide DHCP.

## Safety rules

- Keep local keyboard/monitor access to the new gateway throughout the work.
- Do not use `nixos-rebuild switch` for the first network change. Build it,
  install it as the next boot generation, and reboot from the local console.
- Keep `enp3s0` disconnected from the production LAN until the old gateway has
  stopped using `192.168.10.1`.
- The current configuration provides native Kea DHCP on the trusted LAN only.
  Do not activate it on the production LAN while the old AdGuard DHCP server is
  reachable. The IoT LAN still requires manual addressing.
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

On the new gateway, create the state directories and copy the backup. Use the
old gateway's current address (`192.168.10.1` before the temporary WAN is
added, or `192.168.20.1` afterward):

```bash
sudo install -d -m 0750 /var/lib/adguardhome
sudo install -d -m 0750 /var/lib/adguardhome/conf
sudo install -d -m 0750 /var/lib/adguardhome/work
scp dejima@192.168.10.1:AdGuardHome.yaml.backup /tmp/AdGuardHome.yaml
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
`end0` interface. Add the IoT network to the existing DNS-client allowlist:

```yaml
dns:
  ratelimit: 100
  ratelimit_subnet_len_ipv4: 32
  ratelimit_subnet_len_ipv6: 128
  allowed_clients:
    - 127.0.0.1
    - 192.168.10.0/24
    - 192.168.50.0/24
    - 100.64.0.0/10
```

Add the new wildcard rewrite:

| Name | Answer |
| --- | --- |
| `*.dejima.men` | `192.168.10.1` |

Retain the existing `.sv`, `*.n100.lan`, and `*.n100.local` rewrites during
migration. `*.n100.lan` continues to resolve directly to `192.168.10.10`.

The existing `users: []` setting disables authentication; it does not launch an
account-creation wizard. Before starting the container, generate a bcrypt hash:

```bash
nix --extra-experimental-features 'nix-command flakes' \
  shell nixpkgs#apacheHttpd \
  -c htpasswd -nB -C 10 admin
```

Place only the hash after `admin:` in the persistent configuration:

```yaml
users:
  - name: admin
    password: "$2y$10$..."
```

Use the original plaintext password to log in; never enter the hash as the
password. The container binds its UI to host loopback, and Nginx exposes the
authenticated UI as `https://dns.dejima.men` on trusted interfaces.

## Verify the temporary WAN

The old gateway uses Wi-Fi for Internet access. For testing without taking the
production LAN offline, keep its existing `192.168.10.1/24` address and add a
temporary secondary address on the old gateway:

```bash
sudo ip address add 192.168.20.1/24 dev end0
```

This command is intentionally temporary and must be repeated if the old
gateway reboots. Keep new gateway `enp3s0` disconnected from the production
switch. New gateway `enp2s0` may remain attached to the same temporary Layer 2
network during testing; it uses only `192.168.20.2/24`.

After booting the staged configuration, run on the new gateway:

```bash
ip -brief address show enp2s0
ip route
ping -c 3 192.168.20.1
curl --noproxy '*' --fail --head https://github.com/
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

If the containers attempted to start before the temporary WAN was available,
restart them after Internet access works:

```bash
sudo systemctl restart docker-adguardhome.service docker-tailscale.service
```

Retry ACME issuance if it also ran before the WAN was available:

```bash
sudo systemctl restart acme-dejima.men.service
sudo systemctl reload nginx
```

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
curl --noproxy '*' --fail --head https://github.com/
```

Confirm that the `*.dejima.men` rewrite returns `192.168.10.1`, then open
`https://dns.dejima.men` and log in as `admin` with the plaintext password used
to generate the bcrypt hash. A 502 response from an individual Kubernetes
service is expected before the production LAN is attached; it still proves
DNS, TLS, and Nginx were reached.

On a macOS test client, disable Wi-Fi to avoid two simultaneous routes to
`192.168.10.0/24`. If the wired service is named `USB 10/100 LAN`, configure its
DNS explicitly with:

```bash
sudo networksetup -setdnsservers "USB 10/100 LAN" 192.168.10.1
```

After testing, restore that service and disconnect it from `enp3s0`:

```bash
sudo networksetup -setdhcp "USB 10/100 LAN"
sudo networksetup -setdnsservers "USB 10/100 LAN" Empty
```

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
2. Add temporary `192.168.20.1/24` to old gateway `end0` while retaining both
   its Wi-Fi Internet connection and existing `192.168.10.1/24` address.
3. Verify new gateway `enp2s0` uses `192.168.20.2/24` and complete the temporary
   WAN checks above without interrupting the production LAN.
4. Complete the isolated client tests on `enp3s0`.
5. Build the native NixOS Kea DHCP configuration. Its dynamic pool is
   `192.168.10.150` through `192.168.10.250`; confirm that the old AdGuard DHCP
   server has no active leases in this range before continuing.
6. Back up the final old AdGuard state and confirm the migrated container has
   the required rewrites, filters, allowed clients, and administrator account.
7. Withdraw the old Tailscale subnet route and approve the new `/32` route.
8. Stop the old DHCP service, remove or disable the old gateway's
   `192.168.10.1/24` address, and confirm it no longer owns that address. Keep
   its temporary `192.168.20.1/24` address for the new gateway WAN.
9. Move the production LAN connection to new gateway `enp3s0`. If practical,
   place the temporary old-to-new WAN link on a direct cable or separate switch
   rather than sharing the production LAN Layer 2 network.
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
