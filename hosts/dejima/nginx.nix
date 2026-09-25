{ config, ... }:

let
  forwardedProxyHeaders = ''
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Server $hostname;
  '';

  proxyHeaders = ''
    proxy_set_header Host $host;
    ${forwardedProxyHeaders}
  '';

  traefikProxy = {
    forceSSL = true;
    useACMEHost = "dejima.men";
    locations."/" = {
      proxyPass = "http://traefik";
      proxyWebsockets = true;
      extraConfig = ''
        # Preserve client and browser-facing HTTPS information for applications
        # behind Traefik.
        proxy_request_buffering off;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        ${proxyHeaders}
      '';
    };
  };

  largeDataTraefikProxy = traefikProxy // {
    locations."/" = traefikProxy.locations."/" // {
      # Stream large downloads and media without using gateway disk for proxy
      # response buffers.
      extraConfig = traefikProxy.locations."/".extraConfig + ''
        proxy_buffering off;
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
        ${proxyHeaders}
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
    # Define proxy headers in each location so Argo CD can override Host.
    recommendedProxySettings = false;
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
          extraConfig = proxyHeaders;
        };
      };

      "mealie.dejima.men" = traefikProxy;
      "nextcloud.dejima.men" = largeDataTraefikProxy;
      "homepage.dejima.men" = traefikProxy;
      "authentik.dejima.men" = traefikProxy;
      "n8n.dejima.men" = traefikProxy;
      "echo.dejima.men" = traefikProxy;
      "myapp.dejima.men" = traefikProxy;
      "vaultwarden.dejima.men" = traefikProxy;
      "it-tools.dejima.men" = traefikProxy;
      "linkwarden.dejima.men" = traefikProxy;
      "jellyfin.dejima.men" = largeDataTraefikProxy;
      "forgejo.dejima.men" = traefikProxy;
      "paperless.dejima.men" = traefikProxy;
      "stirling-pdf.dejima.men" = traefikProxy;
      "netdata.dejima.men" = traefikProxy;
      "navidrome.dejima.men" = traefikProxy;
      "wud.dejima.men" = traefikProxy;

      # Home Assistant is a direct IoT-network service, not a Kubernetes one.
      "homeassistant.dejima.men" = homeAssistantProxy;

      # Immich is exposed by its host-based Traefik ingress.  It handles large
      # photo/video uploads, so retain the unbuffered large-data proxy settings.
      "immich.dejima.men" = largeDataTraefikProxy;

      # OpenMediaVault runs directly on the NAS, outside Kubernetes.
      "pi-nas.dejima.men" = {
        forceSSL = true;
        useACMEHost = "dejima.men";
        locations."/" = {
          proxyPass = "http://192.168.10.100";
          proxyWebsockets = true;
          extraConfig = proxyHeaders;
        };
      };

      # Argo CD is served directly from the Kubernetes node's LAN endpoint.
      # Use its stable address: the gateway itself uses public resolvers and
      # cannot resolve the LAN-only argocd.n100.lan hostname during startup.
      "argocd.dejima.men" = {
        forceSSL = true;
        useACMEHost = "dejima.men";
        locations."/" = {
          proxyPass = "http://192.168.10.10";
          proxyWebsockets = true;
          extraConfig = ''
            # Traefik routes Argo CD only for its internal LAN hostname.
            proxy_set_header Host argocd.n100.lan;
            ${forwardedProxyHeaders}
          '';
        };
      };

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
