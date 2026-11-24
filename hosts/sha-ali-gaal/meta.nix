{
  system = "x86_64-linux";
  description = "Test Server";

  roles = [
    "server"
  ];

  profiles = [
    "cn"
  ];

  deployment = {
    targetHost = "sha-ali-gaal.server.allenyou.wang";
    targetPort = 2333;
    sshUser = "deploy";
    buildOnRemote = false;
    tags = [
      "server"
      "sha"
      "ali"
      "sha-ali-gaal"
    ];
  };
}
