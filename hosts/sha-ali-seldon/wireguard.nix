{
  config,
  terminus,
  ...
}:
{
  age.secrets.wireguardPrivateKeyFile = terminus.secrets.secret {
    name = "nexusnet/sha-ali-seldon.priv";
  };

  age.secrets.home-hardin-wireguardPresharedKeyFile = terminus.secrets.secret {
    name = "nexusnet/home-hardin_sha-ali-seldon.psk";
  };

  age.secrets.lap-fallom-wireguardPresharedKeyFile = terminus.secrets.secret {
    name = "nexusnet/lap-fallom_sha-ali-seldon.psk";
  };

  age.secrets.lap-yenner-wireguardPresharedKeyFile = terminus.secrets.secret {
    name = "nexusnet/lap-yenner_sha-ali-seldon.psk";
  };

  terminus.nexusnet = {
    enable = true;
    addresses = [ "192.168.103.1/24" ];
    listenPort = 10500;
    privateKeyFile = config.age.secrets.wireguardPrivateKeyFile.path;

    nat = {
      enable = true;
      externalInterface = "eth0";
      source = "192.168.103.0/24";
    };

    peers = {
      home-hardin = {
        preSharedKeyFile = config.age.secrets.home-hardin-wireguardPresharedKeyFile.path;
        publicKey = "ONtA5KF53ekWNDrb1owlsvvvVgaQGd4wPmtRZargrzY=";
        allowedIPs = [
          "192.168.103.3/32"
          "192.168.100.0/24"
        ];
      };
      lap-fallom = {
        preSharedKeyFile = config.age.secrets.lap-fallom-wireguardPresharedKeyFile.path;
        publicKey = "pGv6qXxK5Rtb4XEy6eSe1VCiR4SLX1MoIOo5yKteMkE=";
        allowedIPs = [ "192.168.103.2/32" ];
      };
      lap-yenner = {
        preSharedKeyFile = config.age.secrets.lap-yenner-wireguardPresharedKeyFile.path;
        publicKey = "o8OVSPXZcoptTO6JIKzYadMqNLFeWV8UhlJVCWnUxFk=";
        allowedIPs = [ "192.168.103.4/32" ];
      };
    };
  };

  terminus.wireguardExporter = {
    enable = true;
    latestHandshakeDelay = true;
  };
}
