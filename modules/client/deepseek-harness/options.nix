# DeepSeek Harness 用户级实例（Home Manager）的选项。
#
# 两层开关：
#   - `terminus.deepseekHarness.client.enable` 只负责安装 dsh、设置 DSH_HOME；
#   - `terminus.deepseekHarness.client.service.enable` 才注册 systemd user unit。
#
# 每个启用 service 的用户会得到独立的 `<service.name>.service`（user unit）、
# 独立的 DSH_HOME、数据目录和端口。不创建系统用户、不碰防火墙。系统级实例见
# `modules/server/deepseek-harness`。
#
# 用法（homes/<user>/<client-host>.nix 或全局 home 配置）：
#
#   terminus.deepseekHarness.client = {
#     enable = true;                  # 安装 dsh、设置 DSH_HOME
#     service = {
#       enable = true;                # 再注册 systemd user unit
#       port = 3081;
#       environment.LANG = "zh_CN.UTF-8";
#       path.mode = "merge";          # 模块工具 + 继承的用户 PATH
#     };
#   };
#
# 如需追加任意 systemd 设置，可直接定义
# `systemd.user.services.<service.name>`；Home Manager 会与模块生成的 unit
# 合并（列表追加；标量冲突用 lib.mkForce 覆盖）。
{
  lib,
  pkgs,
  self,
  ...
}:
{
  options.terminus.deepseekHarness.client = {
    enable = lib.mkEnableOption "安装用户级 DeepSeek Harness (dsh) 并设置 DSH_HOME";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.deepseek-harness;
      defaultText = lib.literalExpression "self.packages.\${pkgs.stdenv.hostPlatform.system}.deepseek-harness";
      description = ''
        `dsh` 包。默认取本 flake 的 `packages.<system>.deepseek-harness`；
        通常不需要覆盖。
      '';
    };

    dataDir = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.pathWith {
          inStore = false;
          absolute = true;
        }
      );
      default = null;
      example = "/home/alice/.local/share/deepseek-harness";
      description = ''
        用户实例的数据目录，`DSH_HOME` 指向该目录。

        为 `null`（默认）时使用
        `~/.local/share/deepseek-harness`（基于当前用户的
        {option}`home.homeDirectory`）。启用 service 时由启动脚本以当前用户
        身份创建并设为 0700；只启用 `client.enable` 时由 dsh 首次运行时自行
        创建。

        必须写成绝对路径字符串；Nix 路径字面量会被复制进 store，不能当作
        运行期可写目录。
      '';
    };

    service = {
      enable = lib.mkEnableOption "注册 DeepSeek Harness 为 systemd user service";

      name = lib.mkOption {
        type = lib.types.str;
        default = "deepseek-harness";
        example = "deepseek-harness-work";
        description = ''
          systemd user unit 名称（不含 `.service` 后缀）。需要和同一用户下
          其他 unit 区分时修改它；直接覆盖 systemd 配置时的路径也会随之变为
          `systemd.user.services.<name>`。
        '';
      };

      target = lib.mkOption {
        type = lib.types.str;
        default = "default.target";
        example = "graphical-session.target";
        description = ''
          启动目标：写入 unit 的 `After=` 和 `Install.WantedBy=`。
        '';
      };

      profile = lib.mkOption {
        type = lib.types.str;
        default = "web";
        example = "web";
        description = ''
          传给 `dsh --profile` 的 profile 名称。默认使用内置的 `web` profile。
        '';
      };

      fromDefaultProfile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "web";
        description = ''
          若非 `null`，启动时如果 `DSH_HOME/profiles/<profile>` 不存在，就用
          `dsh --profile <profile> --from-default-profile <value> --dump-config`
          从内置模板创建它。旧 home-ebeling 的 `web-server` 自定义 profile
          对应 `profile = "web-server"; fromDefaultProfile = "web";`。

          为 `null`（默认）时不做预初始化；`web` 等内置 profile 会在 dsh
          首次启动时自动创建，自定义 profile 需要你自行准备。
        '';
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        example = "127.0.0.1";
        description = ''
          监听地址，以 `--host` 传给 `dsh`。上游只接受一个具体的本机 IPv4/IPv6
          地址（例如 `127.0.0.1` 或 `::1`），不接受 `0.0.0.0` / `::` 通配地址。
          用户级实例默认只监听回环地址，通过 SSH 端口转发或本机浏览器访问。
        '';
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 0;
        example = 3081;
        description = ''
          监听端口，以 `--port` 传给 `dsh`。

          `0`（默认）表示由内核分配一个空闲端口，多个用户同时启用时天然不会
          冲突；实际端口会打印在 `journalctl --user -u <service.name>` 中，
          重启后可能变化。需要稳定地址时设置固定端口，并确保同一主机上每个
          用户使用不同端口。
        '';
      };

      publicUrl = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "http://127.0.0.1:3081/";
        description = ''
          对外访问地址，以 `--public-url` 传给 `dsh`；`null` 时不下发该参数。
          上游通常要求以 `/` 结尾。
        '';
      };

      trustedHosts = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "dsh.example.com" ];
        description = ''
          额外的可信 Host，逐个以 `--trusted-host` 传给 `dsh`。通过反向代理
          访问这个用户实例时，把外部域名写在这里。
        '';
      };

      openBrowser = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          是否让 `dsh` 在启动时尝试打开浏览器。默认 `false`，即传入
          `--no-open`；用户级 unit 通常在登录时启动，打开浏览器一般不是
          期望行为。
        '';
      };

      environmentFile = lib.mkOption {
        type = lib.types.nullOr lib.types.externalPath;
        default = null;
        example = "/run/secrets/deepseek-harness-user.env";
        description = ''
          当前用户可读的环境变量文件（`KEY=VALUE`），由 systemd user unit 的
          `EnvironmentFile=` 读取，并在 `Environment=` 之后覆盖同名变量。
          DSH 需要的 API key 等敏感值放在这里，不要写进 Nix store。

          agenix 示例：`environmentFile = config.age.secrets.deepseek-harness-user.path;`
          （secret 的 owner 必须是当前用户，否则 user unit 读不到）。
        '';
      };

      environment = lib.mkOption {
        type = lib.types.attrsOf (lib.types.nullOr lib.types.str);
        default = { };
        example = {
          LANG = "zh_CN.UTF-8";
          HTTPS_PROXY = "http://127.0.0.1:7890";
          NO_PROXY = null; # 删除默认值（如果有）
        };
        description = ''
          对 service 环境变量的增删改。字符串新增/覆盖，`null` 删除同名默认
          变量。默认变量为 `HOME`、`DSH_HOME`、`SHELL`、`LANG`。

          `PATH` 被保留给 {option}`terminus.deepseekHarness.client.service.path`，
          `DSH_HOME` 由 {option}`terminus.deepseekHarness.client.dataDir` 控制；
          在这里设置这两个变量会触发断言失败。
        '';
      };

      path = {
        mode = lib.mkOption {
          type = lib.types.enum [
            "managed"
            "inherit"
            "merge"
          ];
          default = "managed";
          description = ''
            PATH 策略：

            - `managed`（默认）：PATH 只包含模块管理的包集合，不继承用户
              systemd manager 的 PATH。
            - `inherit`：不覆盖 PATH，完全继承用户 systemd manager 的 PATH；
              `packages` / `extraPackages` 会被忽略。
            - `merge`：把模块管理的包集合放在继承的 PATH 前面，用户原有工具
              仍作为 fallback。
          '';
        };

        packages = lib.mkOption {
          type = lib.types.nullOr (lib.types.listOf lib.types.package);
          default = null;
          defaultText = "模块内置的 agent 工具集";
          description = ''
            模块管理的包集合。`null`（默认）使用内置的 agent 工具集；设置列表
            会整体替换它。只追加工具请用
            {option}`terminus.deepseekHarness.client.service.path.extraPackages`。
          '';
        };

        extraPackages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
          description = ''
            追加到模块管理包集合的包。`inherit` 模式下忽略；需要在继承 PATH
            的基础上追加时请用 `mode = "merge"`。
          '';
        };
      };

      extraArgs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [
          "--tls-cert"
          "/run/secrets/dsh-cert.pem"
        ];
        description = ''
          追加到 `dsh` 命令行末尾的参数；TLS、`--patch` 等未单独建模的启动
          参数可以在这里传入。
        '';
      };
    };
  };
}
