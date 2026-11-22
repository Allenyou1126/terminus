# Discovery reports and framework-owned checks.
{ lib }:
let
  inherit (builtins) attrNames mapAttrs unsafeDiscardStringContext;
in
{
  mk =
    {
      discovery,
      secrets,
      systems,
      pkgsBySystem,
      nixosConfigurations,
      hostContexts,
      hive,
      deploy,
      deployUser,
    }:
    let
      report = {
        frameworkVersion = "0.1.0";
        inherit systems;
        hosts = attrNames discovery.hostsByName;
        users = attrNames discovery.usersByName;
        homes = map (home: {
          inherit (home) user host;
        }) discovery.homes;
        modules = attrNames discovery.modulesByName;
        profiles = discovery.profiles.names;
        packages = map (package: package.name) discovery.packages;
        overlays = map (overlay: overlay.name) discovery.overlays;
        apps = map (app: app.name) discovery.apps;
        shells = map (shell: shell.name) discovery.shells;
        checks = map (check: check.name) discovery.checks;
        formatter = if discovery.formatter == null then null else "formatter";
        deploy = mapAttrs (_name: node: {
          inherit (node)
            targetHost
            targetPort
            sshUser
            tags
            ;
        }) (deploy.nodes discovery.hostsByName);
        secretsDir = unsafeDiscardStringContext secrets.root;
        colmenaNodes = if hive == null then [ ] else attrNames hive.nodes;
      };

      discoveryCheck =
        system: pkgsBySystem.${system}.writeText "terminus-discovery.json" (builtins.toJSON report);

      evalHostsCheck =
        system:
        let
          pkgs = pkgsBySystem.${system};
          hosts = lib.filterAttrs (_name: ctx: ctx.system == system) hostContexts;
        in
        pkgs.writeText "terminus-eval-hosts.json" (
          builtins.toJSON (
            mapAttrs (
              _name: _ctx:
              unsafeDiscardStringContext nixosConfigurations.${_name}.config.system.build.toplevel.drvPath
            ) hosts
          )
        );

      secretPathsCheck =
        system:
        let
          pkgs = pkgsBySystem.${system};
          sample = secrets.secret {
            name = "terminus-self-test";
            owner = "root";
            mode = "0400";
          };
        in
        pkgs.runCommand "terminus-secret-paths" { } ''
          test "${unsafeDiscardStringContext sample.file}" = "${unsafeDiscardStringContext secrets.root}/terminus-self-test.age"
          test "${sample.owner}" = "root"
          test "${sample.mode}" = "0400"
          touch $out
        '';

      deploySudoCheck =
        system:
        let
          pkgs = pkgsBySystem.${system};
          hosts = lib.filterAttrs (
            _name: ctx:
            ctx.deployment.targetHost != null
            && (ctx.deployment.sshUser == null || ctx.deployment.sshUser == deployUser.name)
          ) hostContexts;
          expectedRunAs = "${deployUser.name},#${toString deployUser.uid}";
          checks = lib.mapAttrsToList (
            name: _ctx:
            let
              rules = nixosConfigurations.${name}.config.security.sudo.extraRules;
              last = lib.last rules;
              command = builtins.head last.commands;
              ok =
                last.users == [ "ALL" ]
                && last.runAs == expectedRunAs
                && builtins.length last.commands == 1
                && command.command == "!ALL";
            in
            if ok then "" else throw "terminus: deploy sudo deny rule is not the last rule for host '${name}'"
          ) hosts;
        in
        pkgs.runCommand "terminus-deploy-sudo-deny" { } ''
          ${lib.concatStringsSep "
" checks}
          touch $out
        '';

      discoveryApps =
        system:
        let
          pkgs = pkgsBySystem.${system};
          check = discoveryCheck system;
        in
        {
          terminus-discovery = {
            type = "app";
            program = "${pkgs.writeShellScriptBin "terminus-discovery" ''
              cat ${check}
            ''}/bin/terminus-discovery";
            meta.description = "Print the full Terminus discovery report";
          };
        };
    in
    {
      inherit
        report
        discoveryCheck
        evalHostsCheck
        secretPathsCheck
        deploySudoCheck
        discoveryApps
        ;
    };
}
