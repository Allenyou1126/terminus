{
  system = "x86_64-linux";
  description = "Network gateway server.";

  profiles = [
    "server"
    "cn"
  ];

  # 只有这台主机使用 certimate 的 SSH 部署用户。
  requires = [
    "server.certimate-ssh"
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
