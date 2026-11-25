{
  system = "x86_64-linux";
  description = "Network gateway server.";

  roles = [
    "server"
  ];

  profiles = [
    "cn"
  ];

  deployment = {
    targetHost = "sha-ali-seldon";
    targetPort = 2333;
    sshUser = "deploy";
    buildOnRemote = false;
    tags = [
      "server"
      "sha"
      "ali"
      "sha-ali-seldon"
    ];
  };
}
