{ config, pkgs, domainNames, ... }:

{
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    clientMaxBodySize = "0";

    commonHttpConfig = ''
      proxy_headers_hash_max_size 1024;
      proxy_headers_hash_bucket_size 128;
    '';

    virtualHosts = {
      # AdGuard Home
      "${domainNames.adguard}" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:3000";
        };
      };

      # Homepage
      "${domainNames.homepage}" = {
        locations."/" = {
          proxyPass = "http://n100.local:3000";
        };
      };

      # pi nas
      "${domainNames.piNas}" = {
        locations."/" = {
          proxyPass = "http://pi-nas.local";
        };
      };

      "${domainNames.immich}" = {
        extraConfig = ''
          client_max_body_size 0;
        '';

        locations."/" = {
          proxyPass = "http://n100.local:2283";
          proxyWebsockets = true;

          extraConfig = ''
            proxy_request_buffering off;
            proxy_buffering off;

            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            proxy_read_timeout 600s;
            proxy_send_timeout 600s;
            client_body_timeout 600s;
          '';
        };
      };

      # Homeassistant
      "${domainNames.homeassistant}" = {
        locations."/" = {
          proxyPass = "http://homeassistant.local:8123";
          extraConfig = ''
            # websckes
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
          
            # tell a client's IP to HA
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          '';
        };
      };

      /*
      "${domainNames.nextcloud}" = {
        listen = [{ addr = "0.0.0.0"; port = 80; }];
        locations."/" = {

          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            proxy_redirect off;
            
            # timeout, for big files
            proxy_read_timeout 3600s;
            proxy_connect_timeout 3600s;

            set $backend "http://centre.local:5544";
            proxy_pass $backend;
          '';
        };

        # for app
        extraConfig = ''
          location = /.well-known/carddav { return 301 $scheme://$host/remote.php/dav; }
          location = /.well-known/caldav  { return 301 $scheme://$host/remote.php/dav; }
        '';
      };
      */
    };
  };
}

