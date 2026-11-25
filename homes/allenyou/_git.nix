{
  lib,
  terminus,
  ...
}:
let
  # 仅真实 client host 生效；standalone home（host == null）保持原有行为。
  isClientHost =
    terminus.host != null
    && (terminus.host.roles == null || builtins.elem "client" terminus.host.roles);
in
{
  programs.git.settings = {
    user = {
      name = "Allen You";
      email = "i@allenyou.wang";
    }
    // lib.optionalAttrs isClientHost {
      signingkey = "i@allenyou.wang";
    };
  }
  // lib.optionalAttrs isClientHost {
    http.sslverify = false;
    commit.gpgsign = true;
    core.editor = "vim";
  };
}
