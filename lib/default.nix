# Framework entry point.
{ lib }:
let
  errors = import ./internal/errors.nix { inherit lib; };

  version = {
    major = 0;
    minor = 1;
    patch = 0;
    string = "0.1.0";
  };
in
{
  inherit version;

  mkFlake =
    args:
    let
      inputs = args.inputs or (throw "terminus: mkFlake requires `inputs`");
      self = args.self or (throw "terminus: mkFlake requires `self`");
      root = args.root or self.outPath;

      requestedSystems = if args ? systems && args.systems != null then args.systems else [ ];

      initialKnownSystems = lib.unique (
        requestedSystems
        ++ [
          "x86_64-linux"
          "aarch64-linux"
        ]
      );

      discovery = import ./discover.nix {
        inherit lib root;
        knownSystems = initialKnownSystems;
      };

      hostSystems = map (host: host.meta.system) discovery.hosts;

      packageSystems = lib.concatMap (
        package:
        if package.system != null then
          [ package.system ]
        else if package.meta.systems == null then
          [ ]
        else
          package.meta.systems
      ) discovery.packages;

      outputSystems = lib.concatMap (
        entry: if entry.meta.systems == null then [ ] else entry.meta.systems
      ) (discovery.overlays ++ discovery.apps ++ discovery.shells ++ discovery.checks);

      formatterSystems =
        if discovery.formatter == null || discovery.formatter.meta.systems == null then
          [ ]
        else
          discovery.formatter.meta.systems;

      derivedSystems = lib.unique (
        requestedSystems ++ hostSystems ++ packageSystems ++ outputSystems ++ formatterSystems
      );

      systems = if derivedSystems == [ ] then [ "x86_64-linux" ] else derivedSystems;

      firstSystem = builtins.head systems;

      nixpkgsConfig = (args.nixpkgs or { }).config or { };
      nixpkgsOverlays = (args.nixpkgs or { }).overlays or [ ];

      colmenaConfig = args.colmena or { };
      colmenaEnabled = colmenaConfig.enable or true;
      allowApplyAll = colmenaConfig.allowApplyAll or false;
      deployUser =
        colmenaConfig.deployUser or {
          name = "deploy";
          uid = 1001;
        };

      homeConfig = args.home or { };
      embed = homeConfig.embed or true;
      useGlobalPkgs = homeConfig.useGlobalPkgs or true;
      homeStandalone = homeConfig.standalone or true;
      extraHomeModules = homeConfig.modules or [ ];
      homeSpecialArgs = homeConfig.specialArgs or { };

      nixosConfig = args.nixos or { };
      extraNixosModules = nixosConfig.modules or [ ];
      nixosSpecialArgs = nixosConfig.specialArgs or { };

      outputsConfig = args.outputs or { };
      extraOutputs = outputsConfig.extra or { };

      secretsDir = args.secretsDir or (root + "/secrets");
      secretsIdentityPaths = args.secretsIdentityPaths or [ "/etc/ssh/ssh_host_ed25519_key" ];

      homeTools = import ./home.nix { inherit inputs lib; };
      modulesTools = import ./modules.nix { inherit lib; };
      deployTools = import ./deploy.nix { inherit lib; };
      outputsTools = import ./outputs.nix { inherit inputs self lib; };
      hiveTools = import ./hive.nix {
        inherit inputs lib;
        nixpkgs = inputs.nixpkgs;
      };
      diagnosticsTools = import ./diagnostics.nix { inherit lib; };
      secretTools = import ./secret.nix { inherit lib; };
      hostsTools = import ./hosts.nix { inherit inputs self lib; };

      overlays = outputsTools.overlays { inherit discovery; };
      overlayFns = builtins.attrValues overlays;

      pkgsBySystem = lib.genAttrs systems (
        system:
        import inputs.nixpkgs {
          inherit system;
          config = nixpkgsConfig;
          overlays = overlayFns ++ nixpkgsOverlays;
        }
      );

      secrets = secretTools.mk { inherit secretsDir; };

      _inputs =
        let
          checks = [
            (if inputs ? nixpkgs then true else errors.missingInput "nixpkgs")
            (if inputs ? agenix then true else errors.missingInput "agenix")
            (
              if discovery.homes == [ ] || inputs ? home-manager then true else errors.missingInput "home-manager"
            )
            (if !colmenaEnabled || inputs ? colmena then true else errors.missingInput "colmena")
          ];
        in
        lib.deepSeq checks true;

      hostsResult = hostsTools.mk {
        inherit
          discovery
          secrets
          deployUser
          embed
          useGlobalPkgs
          secretsIdentityPaths
          extraNixosModules
          nixosSpecialArgs
          homeSpecialArgs
          extraHomeModules
          ;
        modules = modulesTools;
        home = homeTools;
        deploy = deployTools;
      };

      hostContexts = hostsResult.contexts;

      nixosConfigurations = lib.mapAttrs (
        _name: ctx:
        inputs.nixpkgs.lib.nixosSystem {
          system = ctx.system;
          specialArgs = ctx.specialArgs;
          modules = ctx.modules ++ [
            { nixpkgs.pkgs = pkgsBySystem.${ctx.system}; }
          ];
        }
      ) hostContexts;

      homeConfigurations = builtins.listToAttrs (
        lib.concatMap (
          home:
          let
            user = discovery.usersByName.${home.user};
          in
          if home.host == null then
            if homeStandalone then
              [
                {
                  name = user.name;
                  value = homeTools.standalone {
                    inherit discovery;
                    pkgs = pkgsBySystem.${firstSystem};
                    inherit user;
                    modules = hostsResult.globalHomeModules {
                      name = user.name;
                      system = firstSystem;
                    };
                    specialArgs = hostsResult.globalHomeSpecialArgs;
                  };
                }
              ]
            else
              [ ]
          else
            let
              ctx = hostContexts.${home.host};
            in
            [
              {
                name = "${user.name}@${home.host}";
                value = homeTools.standalone {
                  inherit discovery;
                  pkgs = pkgsBySystem.${ctx.system};
                  inherit user;
                  host = discovery.hostsByName.${home.host};
                  modules = ctx.homeImports;
                  specialArgs = ctx.homeSpecialArgs;
                };
              }
            ]
        ) discovery.homes
      );

      hiveResult =
        if colmenaEnabled then
          hiveTools.mk {
            inherit
              hostContexts
              pkgsBySystem
              systems
              deployUser
              allowApplyAll
              nixosConfigurations
              ;
            deploy = deployTools;
          }
        else
          {
            hive = null;
            consistencyChecks = { };
          };

      diagnostics = diagnosticsTools.mk {
        inherit
          discovery
          secrets
          systems
          pkgsBySystem
          nixosConfigurations
          hostContexts
          ;
        hive = hiveResult.hive;
        deploy = deployTools;
        inherit deployUser;
      };

      packages = outputsTools.packages {
        inherit discovery pkgsBySystem systems;
      };

      apps = lib.genAttrs systems (
        system:
        (outputsTools.apps {
          inherit discovery pkgsBySystem systems;
        }).${system}
        // {
          colmena = {
            type = "app";
            program = "${inputs.colmena.packages.${system}.colmena}/bin/colmena";
            meta.description = "Pinned Colmena CLI";
          };
        }
        // diagnostics.discoveryApps system
      );

      shells = lib.genAttrs systems (
        system:
        let
          pkgs = pkgsBySystem.${system};
        in
        (outputsTools.shells {
          inherit discovery pkgsBySystem systems;
        }).${system}
        // {
          default = pkgs.mkShell {
            packages = [
              inputs.colmena.packages.${system}.colmena
              inputs.agenix.packages.${system}.default
              pkgs.just
              pkgs.jq
              pkgs.nixfmt
              pkgs.statix
              pkgs.deadnix
              pkgs.treefmt
              pkgs.git
            ];
          };
        }
      );

      checks = lib.genAttrs systems (
        system:
        let
          userChecks =
            (outputsTools.checks {
              inherit discovery pkgsBySystem systems;
            }).${system};

          frameworkChecks = {
            terminus-discovery = diagnostics.discoveryCheck system;
            terminus-eval-hosts = diagnostics.evalHostsCheck system;
            terminus-secret-paths = diagnostics.secretPathsCheck system;
            terminus-deploy-sudo-deny = diagnostics.deploySudoCheck system;
          }
          // lib.optionalAttrs (hiveResult.consistencyChecks ? ${system}) {
            terminus-colmena-consistency = hiveResult.consistencyChecks.${system};
          };
        in
        userChecks // frameworkChecks
      );

      formatter = outputsTools.formatter {
        inherit discovery pkgsBySystem systems;
      };

      libOutput = outputsTools.lib { inherit discovery; };

      registries = modulesTools.registry { inherit discovery; };

      generated = {
        inherit
          nixosConfigurations
          homeConfigurations
          packages
          apps
          checks
          formatter
          libOutput
          ;
        devShells = shells;
        nixosModules = registries.nixosModules;
        homeModules = registries.homeModules;
        inherit overlays;
        lib = libOutput;
      }
      // lib.optionalAttrs colmenaEnabled {
        colmenaHive = hiveResult.hive;
      };

      generated' = removeAttrs generated [ "libOutput" ];
    in
    assert _inputs;
    lib.recursiveUpdate generated' extraOutputs;
}
