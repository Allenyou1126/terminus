# OpenViking —— 面向 AI Agent 的上下文数据库（<https://github.com/volcengine/OpenViking>）。
#
# 搬运自 github:Daaboulex/openviking-nix（MIT），并按 Terminus 的 `packages/`
# 约定重组：`packages/<name>/default.nix` 一一对应 `packages.<system>.<name>`，
# 因此上游 flake 一次打包出的三个产物拆成三个同级目录：
#
# - `../openviking/`（本文件） `openviking`：Python 服务端，内嵌 C++17 pybind11
#   向量引擎，并预置 `ov`（Rust CLI）与 `ragfs_python`（PyO3 扩展）。
# - `../ov-cli/`               `ov-cli`：Rust CLI 客户端，单独构建后由
#   `package.nix` 预置进 Python 包（上游 setup.py 支持 `OV_PREBUILT_BIN_DIR`）。
# - `../ragfs-python/`         `ragfs-python`：RAGFS 的 PyO3 绑定，同样预置进
#   Python 包。
#
# 三个产物共用同目录 `source.nix` 里的 `version` / `src` / Cargo vendor，升级
# 步骤见该文件头部注释。本文件只负责把三者拼成 `package.nix` 需要的参数。
{
  callPackage,
}:

let
  source = callPackage ./source.nix { };
in
callPackage ./package.nix {
  inherit (source) src version python3Packages;

  ov-cli = callPackage ../ov-cli { };
  ragfs-python = callPackage ../ragfs-python { };
}
