{
  system = "x86_64-linux";
  description = "Homelab server";

  roles = [
    "server"
  ];

  profiles = [
    "cn"
  ];

  deployment = {
    # 家里云没有公网 DNS，部署机需要能路由到 192.168.100.0/24
    # （例如通过 WireGuard），并在 ~/.ssh/config 中为这个地址配置
    # keys/deploy 对应的 IdentityFile。
    targetHost = "home-ebeling";
    targetPort = 2333;
    sshUser = "deploy";
    buildOnRemote = false;
    tags = [
      "server"
      "home"
      "home-ebeling"
    ];
  };
}
