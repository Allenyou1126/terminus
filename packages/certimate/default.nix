{
  lib,
  fetchFromGitHub,
  buildGoModule,
  callPackage,
}:
let
  version = "0.4.18";

  src = fetchFromGitHub {
    owner = "certimate-go";
    repo = "certimate";
    rev = "v${version}";
    fetchSubmodules = false;
    sha256 = "sha256-xaH4JYD+EuKucFUH5XhOXbp+A8xNimsXKXPXj5C9w8k=";
  };

  # 前端静态资源单独构建，再由 preBuild 塞进 Go 源码树。
  ui = callPackage ./ui.nix { inherit version src; };
in
buildGoModule {
  pname = "certimate";
  inherit version src;

  vendorHash = "sha256-a8jSXpJ1z7jY72/lfk4fndBP1Q34IDzDWfZxGDiveQo=";

  preBuild = ''
    mkdir -p ./ui
    cp -r ${ui}/dist ./ui/dist
  '';

  env = {
    CGO_ENABLED = 0;
  };

  ldflags = [
    "-s"
    "-w"
  ];

  doCheck = false;

  meta = {
    description = "Open-source self-hosted SSL certificate ACME tool";
    homepage = "https://github.com/certimate-go/certimate";
    license = lib.licenses.mit;
    mainProgram = "certimate";
    platforms = [ "x86_64-linux" ];
  };
}
