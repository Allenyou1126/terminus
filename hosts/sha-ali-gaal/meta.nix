{
  system = "x86_64-linux";
  description = "Test Server";

  roles = [
    "server"
  ];

  deployment = {
    targetHost = "sha-ali-gaal.server.allenyou.wang";
    targetPort = 2333;
    sshUser = "deploy";
    buildOnRemote = false;
    sshOptions = [
      "-i"
      "/home/allenyou/.ssh/terminus_deploy"
      "-o"
      "IdentitiesOnly=yes"
    ];
    tags = [
      "server"
      "sha"
      "ali"
      "sha-ali-gaal"
    ];
  };
}
