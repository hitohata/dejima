{ config, ... }:

let
  traefikProxy = {
    forceSSL = true;
    useACMEHost = "dejima.men";
    locations."/" = {
      proxyPass = "http://traefik";
      proxyWebsockets = true;
      extraConfig = ''
        # Preserve the browser-facing HTTPS request through Traefik to the
        # application.  Authentik uses this to build secure callback URLs.
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port 443;
        proxy_request_buffering off;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
      '';
    };
  };

  homeAssistantProxy = {
    forceSSL = true;
    useACMEHost = "dejima.men";
    locations."/" = {
      proxyPass = "http://192.168.50.2:8123";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
      '';
    };
  };

  immichProxy = {
    forceSSL = true;
    useACMEHost = "dejima.men";
    locations."/" = {
      proxyPass = "http://192.168.10.10:2283";
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

      # Home Assistant is a direct IoT-network service, not a Kubernetes one.
      "homeassistant.dejima.men" = homeAssistantProxy;

      # Immich currently listens directly on the first Kubernetes node.
      "immich.dejima.men" = immichProxy;

      # Keep the former HTTP-only LAN name usable while moving clients to the
      # certificate-covered dejima.men name.  Do not serve HTTPS for .sv.
      "homeassistant.sv" = {
        listen = [{
          addr = "0.0.0.0";
          port = 80;
        }];
        locations."/".return = "301 https://homeassistant.dejima.men$request_uri";
      };

      "immich.sv" = {
        listen = [{
          addr = "0.0.0.0";
          port = 80;
        }];
        locations."/".return = "301 https://immich.dejima.men$request_uri";
      };
    };
  };
}
