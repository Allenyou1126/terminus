{
  system = "x86_64-linux";
  description = "DN42 server";

  roles = [
    "server"
    "dn42"
  ];

  profiles = [
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
