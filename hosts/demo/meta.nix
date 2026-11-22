{
  system = "x86_64-linux";

  roles = [
    "server"
    "workstation"
  ];

  profiles = [ "base" ];

  home = {
    embed = true;
    useGlobalPkgs = true;
  };

  deployment = {
    # Placeholder. Replace with the real address before deploying.
    targetHost = "demo.invalid";
    targetPort = 22;
    sshUser = "deploy";
    buildOnRemote = false;
    tags = [
      "demo"
      "server"
    ];
  };
}
