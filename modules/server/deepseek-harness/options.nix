# DeepSeek Harness 系统服务（NixOS）的选项：enable 与全部配置项。
#
# 这个模块只作为系统级服务使用（meta.nix 关闭 home side），以系统用户运行。
# 用户级、每个用户独享实例的版本见 `modules/client/deepseek-harness`
# （Home Manager + systemd user unit）。
{
  lib,
  pkgs,
  self,
  ...
}:
{
  options.terminus.deepseekHarness.server = {
    enable = lib.mkEnableOption "DeepSeek Harness 系统服务（以系统用户运行）";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.deepseek-harness;
      defaultText = lib.literalExpression "self.packages.\${pkgs.stdenv.hostPlatform.system}.deepseek-harness";
      description = ''
        `dsh` 包。默认取本 flake 的 `packages.<system>.deepseek-harness`；
        通常不需要覆盖。
      '';
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      example = "192.168.100.60";
      description = ''
        监听地址，以 `--host` 传给 `dsh`。上游只接受一个具体的本机 IPv4/IPv6
        地址（例如 `192.168.100.60`），不接受 `0.0.0.0` / `::` 这类通配地址；
        默认只监听回环地址。需要让反向代理或局域网直连时改成具体网卡地址，
        并按需开启 {option}`terminus.deepseekHarness.server.openFirewall`。
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3080;
      description = "监听端口，以 `--port` 传给 `dsh`。";
    };

    publicUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "https://dsh.example.com/";
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
        额外的可信 Host，逐个以 `--trusted-host` 传给 `dsh`。反向代理把外部
        域名转发到本地端口时，把该域名写在这里。
      '';
    };

    dataDir = lib.mkOption {
      type = lib.types.pathWith {
        inStore = false;
        absolute = true;
      };
      default = "/var/lib/deepseek-harness";
      description = ''
        数据目录，同时是服务的 `WorkingDirectory`、默认用户的家目录和
        {option}`terminus.deepseekHarness.server.environmentFile` 之外运行期状态的
        落盘位置；DSH 的 profile 保存在其下的 `.dsh/`。

        必须写成绝对路径字符串（例如 `"/var/lib/deepseek-harness"`）：Nix
        路径字面量会被复制进 store，不能当作运行期可写目录。
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "deepseek-harness";
      description = ''
        运行服务的用户。默认的 `deepseek-harness` 系统用户由本模块创建
        （家目录 = {option}`terminus.deepseekHarness.server.dataDir`）；改成已有用户
        时模块不会创建它，但 tmpfiles 仍会把数据目录的属主设为该用户。
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "deepseek-harness";
      description = ''
        运行服务的用户组。默认组由本模块创建；改成其他组时由你负责保证该组
        存在。
      '';
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.externalPath;
      default = null;
      example = "/run/secrets/deepseek-harness.env";
      description = ''
        以 root 之外权限可读的环境变量文件（`KEY=VALUE`），由 systemd 的
        `EnvironmentFile=` 读取，通常来自 agenix / sops-nix。DSH 需要的 API
        key 等敏感值放在这里，不要写进 Nix store。

        agenix 示例：`environmentFile = config.age.secrets.deepseek-harness-secret.path;`
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        是否在防火墙放行 {option}`terminus.deepseekHarness.server.port`。仅当
        {option}`terminus.deepseekHarness.server.host` 不是回环地址且客户端需要
        直连时开启；通过反向代理访问时保持 `false`。
      '';
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "追加到服务 `PATH` 的包。";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "--verbose" ];
      description = "追加到 `dsh` 命令行末尾的参数。";
    };

    sudo = {
      agent = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            是否允许 DeepSeek Harness 服务用户通过 sudo 提权。默认关闭。

            启用后会为服务用户添加独立的 sudoers 规则（不加入 `wheel`），
            默认允许执行 {option}`terminus.deepseekHarness.server.sudo.agent.commands`
            中的命令且免密码。`commands = [ "ALL" ]` 等价于给 Agent root
            权限，请确认提示注入 / 沙箱风险。
          '';
        };

        commands = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "ALL" ];
          example = [ "/run/current-system/sw/bin/systemctl restart nginx" ];
          description = ''
            允许服务用户通过 sudo 执行的命令（sudoers 语法）。默认
            `[ "ALL" ]` 表示任意命令；建议按实际需要限制。
          '';
        };
      };

      userAccess = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            是否允许其他用户 sudo 到 DeepSeek Harness 服务用户来运行 `dsh`。
            这只授予服务用户级别的代码执行权限（可读取服务环境/状态），不会
            授予 root；需要 root 的操作由
            {option}`terminus.deepseekHarness.server.sudo.serviceControl` 单独控制。

            启用时同时安装全局 `dsh` shell alias。
          '';
        };

        groups = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "wheel" ];
          description = "允许通过 sudo 以服务用户身份运行 `dsh` 的用户组。";
        };
      };

      serviceControl = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            是否允许其他用户通过 sudo 启停 `deepseek-harness` 服务。该规则以
            root 身份执行 `systemctl start/stop/restart deepseek-harness`，
            与 sudo 到服务用户是不同权限。
          '';
        };

        groups = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "wheel" ];
          description = "允许通过 sudo 启停服务的用户组。";
        };
      };
    };
  };
}
