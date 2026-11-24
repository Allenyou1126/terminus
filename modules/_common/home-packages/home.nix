{ pkgs, ... }:
{
  home.packages = with pkgs; [
    zip
    xz
    unzip
    p7zip

    mtr
    iperf3
    dnsutils
    socat
    nmap

    file
    which
    tree
    gnused
    gnutar
    gawk
    zstd
    gnupg

    nix-output-monitor

    htop
    strace
    ltrace
    lsof

    sysstat
    ethtool

    just

    s3cmd
    aliyun-cli
  ];
}
