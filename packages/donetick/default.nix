{
  lib,
  fetchFromGitHub,
  buildGoModule,
  callPackage,
}:
let
  version = "0.1.89";
  rev = "v${version}";

  src = fetchFromGitHub {
    owner = "donetick";
    repo = "donetick";
    rev = rev;
    fetchSubmodules = false;
    sha256 = "sha256-b0l9dwr2wjwcfx4Q5acOcwh2/1stiOf+XwH+2+gtYu8=";
  };

  # 前端静态资源单独构建，再由 preBuild 塞进 Go 源码树。
  frontend = callPackage ./frontend.nix { };
in
buildGoModule {
  pname = "donetick";
  inherit version src;

  vendorHash = "sha256-abI5330bLKF+eBqgPcIadhOp5xDfqL+LmCb4oqn0qgw=";

  subPackages = [ "." ];

  env = {
    CGO_ENABLED = 0;
  };

  # 上游仓库的 frontend/dist 只有一个占位 index.html，
  # frontend/handler.go 用 //go:embed dist 打包，因此构建前整体替换。
  preBuild = ''
    rm -rf ./frontend/dist
    cp -r ${frontend} ./frontend/dist
  '';

  buildFlags = [ "-buildvcs=false" ];

  ldflags = [
    "-s"
    "-w"
    "-X"
    "donetick.com/core/config.Version=${rev}"
    "-X"
    "donetick.com/core/config.Commit=${rev}"
  ];

  doCheck = false;

  # go install ./ 产出的是 module 末段命名的 core，重命名为包名。
  postInstall = ''
    mv $out/bin/core $out/bin/donetick
  '';

  meta = {
    description = "Open-source chore management and scheduling app with an embedded web UI";
    homepage = "https://github.com/donetick/donetick";
    license = lib.licenses.agpl3Only;
    mainProgram = "donetick";
    platforms = [ "x86_64-linux" ];
  };
}
