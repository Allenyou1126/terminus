{
  system = "x86_64-linux";
  description = "Test Server";

  profiles = [
    "server"
    "cn"
  ];

  deployment = {
    targetHost = "sha-ali-gaal";
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
