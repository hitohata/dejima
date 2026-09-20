{ config, ... }:

let
  traefikProxy = {
    forceSSL = true;
    useACMEHost = "dejima.men";
    locations."/" = {
      proxyPass = "http://traefik";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_request_buffering off;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
      '';
    };
  };
in
{
  security.acme = {
    acceptTerms = true;
    defaults.email = "hirohatatro@gmail.com";
    certs."dejima.men" = {
      domain = "dejima.men";
      extraDomainNames = [ "*.dejima.men" ];
      dnsProvider = "cloudflare";
      credentialFiles.CF_DNS_API_TOKEN_FILE =
        config.sops.secrets.cloudflare_dns_api_token.path;
      group = "nginx";
    };
  };

  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    clientMaxBodySize = "0";

    upstreams.traefik.servers = {
      "192.168.10.10:80" = {
        max_fails = 3;
        fail_timeout = "10s";
      };
      "192.168.10.11:80" = {
        max_fails = 3;
        fail_timeout = "10s";
      };
    };

    virtualHosts = {
      "dns.dejima.men" = {
        forceSSL = true;
        useACMEHost = "dejima.men";
        locations."/" = {
          proxyPass = "http://127.0.0.1:3000";
          proxyWebsockets = true;
        };
      };

      "mealie.dejima.men" = traefikProxy;
      "nextcloud.dejima.men" = traefikProxy;
      "homepage.dejima.men" = traefikProxy;
      "authentik.dejima.men" = traefikProxy;
      "n8n.dejima.men" = traefikProxy;
      "echo.dejima.men" = traefikProxy;
      "myapp.dejima.men" = traefikProxy;
      "vaultwarden.dejima.men" = traefikProxy;
      "it-tools.dejima.men" = traefikProxy;
      "linkwarden.dejima.men" = traefikProxy;
      "jellyfin.dejima.men" = traefikProxy;
      "forgejo.dejima.men" = traefikProxy;
      "paperless.dejima.men" = traefikProxy;
      "stirling-pdf.dejima.men" = traefikProxy;
      "netdata.dejima.men" = traefikProxy;
    };
  };
}
