{ lib, ... }:

{
  networking.wg-quick.interfaces.wg0 = {
    address = [
      "10.44.0.2/32"
      "fd44:44:44::2/128"
    ];
    privateKeyFile = "/etc/wireguard/privatekey";

    peers = [
      {
        publicKey = "57/Sht0z5aTUqrBibTjdWeUBjJLXOSvHcsUV4I2IL3E=";
        endpoint = "52.30.107.187:51820";
        allowedIPs = [
          "0.0.0.0/0"
          "::/0"
        ];
        persistentKeepalive = 25;
      }
    ];
  };

  systemd.services.wg-quick-wg0.wantedBy = lib.mkForce [ ];
}
