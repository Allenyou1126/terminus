# server 主机通用模块；具体服务仍由各模块的 enable option 控制。
# certimate-ssh 只被 sha-ali-seldon 使用，由该主机 meta.requires 直接导入。
{
  requires = [
    "server.bird-exporter"
    "server.blackbox-exporter"
    "server.certimate"
    "server.deepseek-harness"
    "server.frps"
    "server.nexusnet"
    "server.nginx-exporter"
    "server.node-exporter"
    "server.openviking"
    "server.postgresql"
    "server.prometheus"
    "server.ssh"
    "server.wireguard-exporter"
  ];
}
