# Xray Client Configuration for NixOS
# 
# Usage:
#   1. Replace YOUR_SERVER_IP with your EC2 instance's public IP
#   2. Replace PUBLIC_KEY_HERE with the server's public key
#      (run on server: xray x25519 -i "YC55FU-JKqGsBiMEWeHQVX3oHXDvKhfktT4RDVpKs3o")
#   3. Import this file in your NixOS configuration.nix:
#      imports = [ ./client-configuration.nix ];
#   4. Run: sudo nixos-rebuild switch
#
# Proxies available after activation:
#   - SOCKS5: 127.0.0.1:1080
#   - HTTP:   127.0.0.1:8080

{ config, pkgs, ... }:

{

  environment.sessionVariables = {
    ALL_PROXY = "socks5h://127.0.0.1:1080";
    all_proxy = "socks5h://127.0.0.1:1080";
    # Optional: use HTTP proxy for apps that don't support SOCKS5
    # HTTP_PROXY = "http://127.0.0.1:8080";
    # HTTPS_PROXY = "http://127.0.0.1:8080";
  };

  services.xray = {
    enable = true;
    settings = {
      log.loglevel = "warning";

      inbounds = [
        {
          tag = "socks";
          port = 1080;
          listen = "127.0.0.1";
          protocol = "socks";
          settings = {
            udp = true;
          };
        }
        {
          tag = "http";
          port = 8080;
          listen = "127.0.0.1";
          protocol = "http";
        }
      ];

      outbounds = [{
        tag = "proxy";
        protocol = "vless";
        settings = {
          vnext = [{
            address = "3.254.156.122";
            port = 443;
            users = [{
              id = "0a0fa7fa-82a0-4bbe-9814-dc5d563de575";
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
            publicKey = "O8pDual2tmGJJMrYg2698PclvmOHgAJf1fiZH_HGDxQ";
            shortId = "a1b2c3d4e5f60708";
            fingerprint = "chrome";
          };
        };
      }];
    };
  };

  environment.systemPackages = with pkgs; [ xray ];
}
