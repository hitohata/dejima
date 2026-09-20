{ ... }: {
  sops = {
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    defaultSopsFile = ../../../secrets/secrets.yaml;
    gnupg.sshKeyPaths = [];
  };

  sops.secrets = {
    tailscale_key = {
      mode = "0400";
    };
    cloudflare_dns_api_token = {
      mode = "0400";
    };
  };
}
