{
  substituterPresets = {
    ustc-mirror = {
      url = "https://mirrors.ustc.edu.cn/nix-channels/store";
      priority = 10;
      trustedPublicKeys = [ ];
    };

    allenyou-cache = {
      url = "https://nix-cache.allenyou.wang";
      priority = 20;
      trustedPublicKeys = [
        "allenyou-nix-cache.lap-fallom.1:rKfa65SLrDQLTGEmp+c90R4vsnGgD9xFoKHrdrvJGRs="
        "allenyou-nix-cache.lax-rn-riose.1:zGDPA3NkInSSjfH5hrYBwYAIu0JyCyE9LDKl/mcDFWE="
        "allenyou-nix-cache.lap-yenner.1:ZqBCrBf8+lu2BN1fGHeJRbStXDZ+TXRqG1NUF3oc9hY="
      ];
    };

    official-cloudflare-mirror = {
      url = "https://nix-cache-official.allenyou.wang";
      priority = 30;
      trustedPublicKeys = [ ];
    };

    official = {
      url = "https://cache.nixos.org";
      priority = 40;
      trustedPublicKeys = [ ];
    };
  };
}
