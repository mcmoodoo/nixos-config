# Xray Client Configuration for NixOS
#
# System-wide routing uses Xray's TUN inbound.
# Routes are installed separately by the xray-routing systemd unit.

{ pkgs, ... }:

let
  serverAddr = "3.255.171.223";
  serverPort = 443;
  serverName = "www.cloudflare.com";
  tunName = "xray0";
  uplinkInterface = "wlp4s0";

  # Root-managed secret file, intentionally kept out of git.
  xraySecretsPath = "/var/lib/secrets/xray-client.env";
in
{
  systemd.tmpfiles.rules = [
    "d /var/lib/secrets 0700 root root -"
  ];

  systemd.services.xray = {
    description = "xray Daemon";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    path = [ pkgs.coreutils ];
    script = ''
      set -eu

      secrets_env="$CREDENTIALS_DIRECTORY/xray-client-secrets"
      runtime_config="$RUNTIME_DIRECTORY/config.json"

      # Source root-managed credentials loaded by systemd.
      . "$secrets_env"

      : "''${XRAY_USER_ID:?missing XRAY_USER_ID in $secrets_env}"
      : "''${XRAY_SHORT_ID:?missing XRAY_SHORT_ID in $secrets_env}"
      : "''${XRAY_PUBLIC_KEY:?missing XRAY_PUBLIC_KEY in $secrets_env}"

      install -Dm600 /dev/null "$runtime_config"

      cat > "$runtime_config" <<EOF
      {
        "log": {
          "loglevel": "warning"
        },
        "inbounds": [
          {
            "tag": "tun-in",
            "protocol": "tun",
            "settings": {
              "name": "${tunName}",
              "MTU": 1500
            }
          }
        ],
        "outbounds": [
          {
            "tag": "proxy",
            "protocol": "vless",
            "settings": {
              "vnext": [
                {
                  "address": "${serverAddr}",
                  "port": ${toString serverPort},
                  "users": [
                    {
                      "id": "$XRAY_USER_ID",
                      "flow": "xtls-rprx-vision",
                      "encryption": "none"
                    }
                  ]
                }
              ]
            },
            "streamSettings": {
              "network": "tcp",
              "security": "reality",
              "realitySettings": {
                "serverName": "${serverName}",
                "publicKey": "$XRAY_PUBLIC_KEY",
                "shortId": "$XRAY_SHORT_ID",
                "fingerprint": "chrome"
              },
              "sockopt": {
                "interface": "${uplinkInterface}"
              }
            }
          },
          {
            "tag": "direct",
            "protocol": "freedom"
          }
        ],
        "routing": {
          "domainStrategy": "AsIs",
          "rules": [
            {
              "type": "field",
              "inboundTag": [ "tun-in" ],
              "ip": [ "geoip:private" ],
              "outboundTag": "direct"
            },
            {
              "type": "field",
              "inboundTag": [ "tun-in" ],
              "outboundTag": "proxy"
            }
          ]
        }
      }
      EOF

      exec ${pkgs.xray}/bin/xray -config "$runtime_config"
    '';
    serviceConfig = {
      Type = "simple";
      DynamicUser = true;
      RuntimeDirectory = "xray";
      LoadCredential = [ "xray-client-secrets:${xraySecretsPath}" ];
      CapabilityBoundingSet = "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
      AmbientCapabilities = "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
      NoNewPrivileges = true;
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  systemd.services.xray-routing = {
    description = "Install system routes for Xray TUN";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" "xray.service" ];
    requires = [ "xray.service" ];
    partOf = [ "xray.service" ];
    path = [ pkgs.coreutils pkgs.gawk pkgs.gnugrep pkgs.iproute2 ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -eu

      server_ip="${serverAddr}"
      tun_if="${tunName}"

      route_line="$(ip -4 route get "$server_ip" | head -n1)"
      real_if="$(printf '%s\n' "$route_line" | grep -oE 'dev [^ ]+' | awk '{print $2}')"
      gateway="$(printf '%s\n' "$route_line" | grep -oE 'via [^ ]+' | awk '{print $2}' || true)"

      if [ -z "$real_if" ]; then
        echo "failed to determine uplink interface for $server_ip" >&2
        exit 1
      fi

      if [ -n "$gateway" ]; then
        ip route replace "$server_ip/32" via "$gateway" dev "$real_if"
      else
        ip route replace "$server_ip/32" dev "$real_if"
      fi

      ip route replace 0.0.0.0/1 dev "$tun_if"
      ip route replace 128.0.0.0/1 dev "$tun_if"
    '';
    postStop = ''
      set -eu

      server_ip="${serverAddr}"
      tun_if="${tunName}"

      ip route del 0.0.0.0/1 dev "$tun_if" 2>/dev/null || true
      ip route del 128.0.0.0/1 dev "$tun_if" 2>/dev/null || true
      ip route del "$server_ip/32" 2>/dev/null || true
    '';
  };

  environment.systemPackages = with pkgs; [ xray ];
}
