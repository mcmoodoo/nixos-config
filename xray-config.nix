# Xray Client Configuration for NixOS
#
# Proxies after activation:
#   - SOCKS5: 127.0.0.1:1080
#   - HTTP:   127.0.0.1:8080

{ config, pkgs, ... }:

let
  serverAddr = "34.251.127.221";
  serverPort = 443;
  userId = "0a0fa7fa-82a0-4bbe-9814-dc5d563de575";
  publicKey = "O8pDual2tmGJJMrYg2698PclvmOHgAJf1fiZH_HGDxQ";
  shortId = "a1b2c3d4e5f60708";
  socksPort = 1080;
  httpPort = 8080;
in
{

  environment.sessionVariables = {
    ALL_PROXY = "socks5h://127.0.0.1:${toString socksPort}";
    all_proxy = "socks5h://127.0.0.1:${toString socksPort}";
    # Optional: use HTTP proxy for apps that don't support SOCKS5
    # HTTP_PROXY = "http://127.0.0.1:${toString httpPort}";
    # HTTPS_PROXY = "http://127.0.0.1:${toString httpPort}";
  };

  services.xray = {
    enable = true;
    settings = {
      log.loglevel = "warning";

      inbounds = [
        {
          tag = "socks";
          port = socksPort;
          listen = "127.0.0.1";
          protocol = "socks";
          settings = {
            udp = true;
          };
        }
        {
          tag = "http";
          port = httpPort;
          listen = "127.0.0.1";
          protocol = "http";
        }
      ];

      outbounds = [{
        tag = "proxy";
        protocol = "vless";
        settings = {
          vnext = [{
            address = serverAddr;
            port = serverPort;
            users = [{
              id = userId;
              flow = "xtls-rprx-vision";
              encryption = "none";
            }];
          }];
        };
        streamSettings = {
          network = "tcp";
          security = "reality";
          realitySettings = {
            serverName = "www.cloudflare.com";
            inherit publicKey shortId;
            fingerprint = "chrome";
          };
        };
      }];
    };
  };

  environment.systemPackages = with pkgs; [ xray ];
}
