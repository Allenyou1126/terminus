{ terminus, ... }:
let
  p = terminus.exports.prometheus;
in
{
  terminus.blackboxExporter = {
    enable = true;
  };

  terminus.prometheus = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9333;
    scrapeInterval = "5s";
    evaluationInterval = "30s";

    staticScrapeJobs = p.mkStaticJobs {
      basic = p.mkTargets [
        (p.mkTarget "172.18.63.50:9100" {
          instance = "sha-ali-gaal";
          location = "sha";
        })
        (p.mkTarget "127.0.0.1:9100" {
          instance = "sha-ali-seldon";
          location = "sha";
        })
        (p.mkTarget "192.161.173.107:9100" {
          instance = "lax-rn-riose";
          location = "lax";
        })
        (p.mkTarget "38.55.97.96:9100" {
          instance = "hkg-dog-darell";
          location = "hkg";
        })
        (p.mkTarget "192.168.100.60:9100" {
          instance = "home-ebeling";
          location = "zzz";
        })
      ];

      prometheus = p.mkTargets [
        (p.mkTarget "127.0.0.1:9333" {
          instance = "sha-ali-gaal";
          location = "sha";
        })
      ];

      coredns_dn42 = p.mkTargets [
        (p.mkTarget "192.161.173.107:9153" {
          instance = "lax-rn-riose";
          location = "lax";
        })
      ];

      frps = p.mkTargets [
        (p.mkTarget "127.0.0.1:9500" {
          instance = "sha-ali-seldon";
          location = "sha";
        })
      ];

      nginx = p.mkTargets [
        (p.mkTarget "127.0.0.1:9090" {
          instance = "sha-ali-seldon";
          location = "sha";
        })
        (p.mkTarget "38.55.97.96:9090" {
          instance = "hkg-dog-darell";
          location = "hkg";
        })
      ];

      bird_dn42 = p.mkTargets [
        (p.mkTarget "192.161.173.107:9324" {
          instance = "lax-rn-riose";
          location = "lax";
        })
      ];

      wireguard = p.mkTargets [
        (p.mkTarget "127.0.0.1:9586" {
          instance = "sha-ali-seldon";
          location = "sha";
        })
        (p.mkTarget "192.161.173.107:9586" {
          instance = "lax-rn-riose";
          location = "lax";
        })
        (p.mkTarget "38.55.97.96:9586" {
          instance = "hkg-dog-darell";
          location = "hkg";
        })
      ];
    };

    blackboxJobs = [
      (p.mkBlackboxJob {
        jobName = "website";
        probes = [
          (p.mkProbe "https://www.allenyou.wang" {
            public = "true";
            description = "Blog";
            instance = "hkg-dog-darell";
            location = "hkg";
          })
          (p.mkProbe "https://lotusland.allenyou.wang" {
            public = "true";
            description = "Allenyou's Lotusland";
            instance = "hkg-dog-darell";
            location = "hkg";
          })
          (p.mkProbe "https://wakapi.allenyou.wang" {
            description = "Wakapi";
            instance = "hkg-dog-darell";
            location = "hkg";
          })
          (p.mkProbe "https://rss.allenyou.wang" {
            description = "Miniflux RSS";
            instance = "hkg-dog-darell";
            location = "hkg";
          })
          (p.mkProbe "https://sub-store.allenyou.wang" {
            description = "Sub Store";
            instance = "hkg-dog-darell";
            location = "hkg";
          })
          (p.mkProbe "https://auth.allenyou.top" {
            description = "ZITADEL Auth";
            instance = "sha-ali-seldon";
            location = "sha";
          })
          (p.mkProbe "https://lg.allenyou.wang" {
            public = "true";
            description = "DN42 Looking Glass";
            instance = "hkg-dog-darell";
            location = "hkg";
          })
          (p.mkProbe "https://grafana.allenyou.top" {
            description = "Grafana";
            instance = "sha-ali-seldon";
            location = "sha";
          })
          (p.mkProbe "https://umami.allenyou.wang" {
            description = "Umami 统计";
            instance = "hkg-dog-darell";
            location = "hkg";
          })
          (p.mkProbe "https://ai.allenyou.wang" {
            description = "Open WebUI";
            instance = "hkg-dog-darell";
            location = "hkg";
          })
          (p.mkProbe "https://gotify.allenyou.wang" {
            description = "Gotify";
            instance = "hkg-dog-darell";
            location = "hkg";
          })
          (p.mkProbe "https://vw.allenyou.wang" {
            description = "Vaultwarden";
            instance = "hkg-dog-darell";
            location = "hkg";
          })
          (p.mkProbe "https://waline.allenyou.wang" {
            public = "true";
            description = "Waline 评论系统";
            instance = "hkg-dog-darell";
            location = "hkg";
          })
          (p.mkProbe "https://dsh.allenyou.top" {
            description = "Remote DeepSeek Harness";
            instance = "home-ebeling";
            location = "home";
          })
          (p.mkProbe "https://allenyou.top" {
            public = "true";
            description = "个人主页";
            instance = "zzz-ali-cdn";
            location = "global";
          })
          (p.mkProbe "https://blog-oss.allenyou.top/placeholder.txt" {
            public = "true";
            description = "静态资源 CDN";
            instance = "zzz-ali-cdn";
            location = "global";
          })
        ];
      })
    ];
  };
}
