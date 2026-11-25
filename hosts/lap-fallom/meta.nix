{
  system = "x86_64-linux";
  description = "Client Laptop running in WSL.";

  roles = [
    "client"
    "wsl"
  ];

  profiles = [
    "cn"
  ];

  deployment = {
    allowLocalDeployment = false;
  };
}
