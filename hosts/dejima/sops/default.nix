{ config, pkgs, inputs, ... }: {
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  sops = {
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    defaultSopsFile = ../../../secrets/secrets.yaml;
    gnupg.sshKeyPaths = [];
  };

  sops.secrets = {
    pihole_password = {
      mode = "0400";
    };
    azure_password = {
      mode = "0400";
    };
    tailscale_key = {
      mode = "0400";
    };
  };
}
