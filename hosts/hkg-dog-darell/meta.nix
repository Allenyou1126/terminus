{
  system = "x86_64-linux";
  description = "Application server.";

  roles = [
    "server"
  ];

  profiles = [
    "cn"
  ];

  deployment = {
    targetHost = "hkg-dog-darell";
    targetPort = 2333;
    sshUser = "deploy";
    buildOnRemote = false;
    tags = [
      "server"
      "hkg"
      "hkg-dog-darell"
    ];
  };
}
