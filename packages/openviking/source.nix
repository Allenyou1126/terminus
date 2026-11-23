# OpenViking 的共享源码固定值：`version` / `src` / Cargo vendor / Python 包集。
#
# Terminus 的 `packages/<name>/default.nix` 一一对应 `packages.<system>.<name>`，
# 所以上游 flake 一次打包出的三个产物在本仓库拆成三个同级目录：
#
# - `../openviking/`   `openviking`：Python 服务端，内嵌 C++17 pybind11 向量引擎，
#                      并预置 `ov`（Rust CLI）与 `ragfs_python`（PyO3 扩展）。
# - `../ov-cli/`       `ov-cli`：Rust CLI 客户端，单独构建后由 package.nix 预置进
#                      Python 包（上游 setup.py 支持 `OV_PREBUILT_BIN_DIR`）。
# - `../ragfs-python/` `ragfs-python`：RAGFS 的 PyO3 绑定，同样预置进 Python 包。
#
# 三个产物共用这里的 `src` 与 Cargo vendor：整个 Rust workspace 只有根目录一个
# Cargo.lock，一次 fetchCargoVendor 覆盖全部 Rust 构建。
#
# 升级步骤（固定输出、可复现）：
#   1. 改下面的 `version`（上游 tag 形如 `v0.5.0`）；
#   2. 重新获取 `src` hash 与 `cargoDeps` hash（`nix build .#openviking` 报
#      hash mismatch 时会给出正确值）；
#   3. 对照上游 pyproject.toml 检查 `package.nix` 里的 PyPI wheel 依赖是否需同步。
{
  fetchFromGitHub,
  python3Packages,
  rustPlatform,
}:

let
  version = "0.5.0";

  # 本仓库 pin 的 nixpkgs 里 Python 3.13.14 重构了 `urllib.robotparser`，导致
  # scrapy / courlan 两个包的上游测试失败（Hydra 上同样失败，所以它们不在
  # binary cache 里）。失败只发生在测试里，运行时行为不受影响；为了让
  # openviking 的依赖闭包能构建，只在这个闭包里关掉这两个包的 check —— 不动
  # 仓库全局 overlay，也不影响其他包的测试。nixpkgs 修好这个 robotparser 回归
  # （或本仓库更新 nixpkgs pin）后可以删掉。
  python3Packages' = python3Packages.overrideScope (
    _final: prev: {
      scrapy = prev.scrapy.overridePythonAttrs (_: {
        doCheck = false;
      });
      courlan = prev.courlan.overridePythonAttrs (_: {
        doCheck = false;
      });
    }
  );

  src = fetchFromGitHub {
    owner = "volcengine";
    repo = "OpenViking";
    rev = "v${version}";
    hash = "sha256-3RXSuRPWla8+phhXZjmQ3r8C/I0TzhKLawB4ZvXF7KI=";
  };

  # 整个 workspace（crates/ov_cli、crates/ragfs、crates/ragfs-python）共用一份
  # Cargo vendor：三者都从根目录 Cargo.lock 解析依赖，因此只需要一个 hash。
  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit src;
    hash = "sha256-hVugRWUTV+JSgahiSLAaNfyUXSYPGritnPOiV+vccDo=";
  };
in
{
  inherit
    version
    src
    cargoDeps
    ;
  python3Packages = python3Packages';
}
