{
  system = "x86_64-linux";
  description = "DN42 server";

  profiles = [
    "server"
    "dn42"
    "global"
  ];

  deployment = {
    targetHost = "lax-rn-riose";
    targetPort = 2333;
    sshUser = "deploy";
    buildOnRemote = false;
    tags = [
      "server"
      "dn42"
      "lax"
      "lax-rn-riose"
    ];
  };
}
