{
  system = "x86_64-linux";
  description = "Client Laptop running in WSL.";

  profiles = [
    "client"
    "wsl"
    "cn"
  ];

  deployment = {
    allowLocalDeployment = false;
  };
}
