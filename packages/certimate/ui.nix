{
  lib,
  buildNpmPackage,
  nodejs_24,
  version,
  src,
}:
buildNpmPackage {
  pname = "certimate-ui";
  inherit version src;

  env = {
    NODE_OPTIONS = "--max-old-space-size=4096";
  };

  npmDepsHash = "sha256-Lxcz0ztIn4vH+Q4WFcCqlRJOklUyyC2FvVRUqd8Da5I=";
  sourceRoot = "${src.name}/ui";
  nodejs = nodejs_24;

  # 依赖由 npm-config-hook 在 configure 阶段装好；这里不要 buildNpmPackage
  # 默认的 npm 打包安装阶段，只把 `vite build` 的产物拷出来。
  dontNpmInstall = true;

  installPhase = ''
    mkdir -p $out/dist
    cp -r dist/* $out/dist/
  '';

  meta = {
    description = "Web UI assets for certimate";
    homepage = "https://github.com/certimate-go/certimate";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}
