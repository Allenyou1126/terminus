{
  lib,
  buildNpmPackage,
  nodejs_24,
  fetchFromGitHub,
}:
let
  version = "1.2.78";

  src = fetchFromGitHub {
    owner = "donetick";
    repo = "frontend";
    rev = "v${version}";
    fetchSubmodules = true;
    sha256 = "sha256-Snw5suEe1MnIQGvimgoCHFiOCbRhQnNLoFkIAbxeDVY=";
  };
in
buildNpmPackage {
  pname = "donetick-frontend";
  inherit version src;

  npmDepsFetcherVersion = 2;
  npmDepsHash = "sha256-tLBPS4POkYG6u8BNrwUf5EKdKzXkJNFXBwOy3HR/C7w=";

  nodejs = nodejs_24;

  # 上游 v1.2.78 的 package-lock.json 有 907/1385 个条目缺 resolved/integrity，
  # nixpkgs 的 prefetch-npm-deps 会跳过这些包，导致离线 npm ci 请求
  # registry packument 时 ENOTCACHED。frontend-package-lock.json 是同一版本
  # 依赖树上只补全 resolved/integrity 的锁文件（依赖版本不变）。
  # 换版本后重新生成：
  #   ./update-frontend-lock.py <上游 package-lock.json> frontend-package-lock.json
  postPatch = ''
    cp ${./frontend-package-lock.json} package-lock.json
  '';

  npmBuildScript = "build";
  npmBuildFlags = [
    "--"
    "--mode"
    "selfhosted"
  ];

  # 上游依赖树里有若干 peer dependency 冲突，npm ci 需要 legacy 解析；
  # 只放在 npmInstallFlags，避免像 npmFlags 那样被追加到 `npm run build` 的
  # 参数里传给 vite。
  npmInstallFlags = [ "--legacy-peer-deps" ];

  # fetcher v2 的缓存同一 key 会有多条记录，npm 需要能写缓存。
  makeCacheWritable = true;

  # npmConfigHook 的 npm rebuild 会执行 sharp 的 install 脚本，该脚本尝试从
  # GitHub 下载 libvips 预编译包；沙箱里没有网络，而且 sharp 只被
  # @capacitor/assets（devDependency）用于图标处理，vite 构建不需要它。
  # 跳过 install 脚本即可，其余语言包都是纯 JS / 可选平台二进制依赖。
  npmRebuildFlags = [ "--ignore-scripts" ];

  installPhase = ''
    mkdir -p $out
    cp -r dist/. $out/
  '';

  meta = {
    description = "Web UI for Donetick";
    homepage = "https://github.com/donetick/frontend";
    license = lib.licenses.agpl3Only;
    platforms = [ "x86_64-linux" ];
  };
}
