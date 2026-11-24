# Pure filesystem discovery. This module never evaluates a NixOS or Home
# Manager configuration; it only reads directory structure and meta.nix files.
{
  lib,
  root,
  knownSystems,
}:
let
  inherit (builtins)
    attrNames
    concatMap
    elem
    filter
    isAttrs
    length
    listToAttrs
    mapAttrs
    pathExists
    removeAttrs
    replaceStrings
    ;

  fs = import ./fs.nix { inherit lib; };
  metadata = import ./metadata.nix { inherit lib; };
  errors = import ./internal/errors.nix { inherit lib; };
  profilesLib = import ./profiles.nix { inherit lib; };

  at = sub: root + "/${sub}";

  listDirSafe = sub: if pathExists (at sub) then fs.listDir (at sub) else [ ];
  listDirsSafe = sub: filter (e: e.type == "directory") (listDirSafe sub);
  listFilesSafe = sub: filter (e: e.type == "regular") (listDirSafe sub);
  nixFilesSafe = sub: filter (e: lib.hasSuffix ".nix" e.name) (listFilesSafe sub);

  knownSystemSet = listToAttrs (
    map (s: {
      name = s;
      value = true;
    }) knownSystems
  );

  readOutputMeta =
    dir:
    if pathExists (dir + "/meta.nix") then
      metadata.normalizeOutputMeta (dir + "/meta.nix") (metadata.readMeta (dir + "/meta.nix"))
    else
      metadata.normalizeOutputMeta (dir + "/meta.nix") { };

  # ---------------------------------------------------------------------------
  # hosts/
  # ---------------------------------------------------------------------------

  parseHost =
    entry:
    let
      dir = entry.path;
      metaPath = dir + "/meta.nix";
      defaultPath = dir + "/default.nix";
      magicNames = [
        "default.nix"
        "hardware.nix"
        "disk.nix"
        "network.nix"
      ];
      rawMeta = if pathExists metaPath then metadata.readMeta metaPath else errors.missingFile metaPath;
      meta = metadata.normalizeHostMeta metaPath rawMeta;
      magicFiles = filter (name: pathExists (dir + "/${name}")) magicNames;
      otherNixFiles = filter (e: !(elem e.name (magicNames ++ [ "meta.nix" ]))) (fs.nixFiles dir);
    in
    if !(pathExists defaultPath) then
      errors.missingFile defaultPath
    else
      {
        name = entry.name;
        inherit
          dir
          metaPath
          defaultPath
          meta
          magicFiles
          otherNixFiles
          ;
        system = meta.system;
        modulePaths = map (name: dir + "/${name}") magicFiles;
      };

  hosts = map parseHost (listDirsSafe "hosts");
  hostsByName = listToAttrs (
    map (h: {
      name = h.name;
      value = h;
    }) hosts
  );

  # ---------------------------------------------------------------------------
  # homes/
  # ---------------------------------------------------------------------------

  homeFiles = concatMap (
    userDir:
    let
      # `_*.nix` are fragments imported by default.nix / <host>.nix, not
      # host-specific home entries. `default.nix` and `<host>.nix` remain the
      # discovered entry points.
      files = filter (e: e.name != "meta.nix" && !(lib.hasPrefix "_" e.name)) (fs.nixFiles userDir.path);
    in
    map (
      file:
      let
        host = lib.removeSuffix ".nix" file.name;
      in
      if file.name == "default.nix" then
        {
          user = userDir.name;
          host = null;
          path = file.path;
        }
      else
        {
          user = userDir.name;
          inherit host;
          path = file.path;
        }
    ) files
  ) (listDirsSafe "homes");

  homes = map (
    home:
    if home.host == null then
      home
    else if hostsByName ? ${home.host} then
      home
    else
      errors.unknownHost home.host
  ) homeFiles;

  homesByUser = listToAttrs (
    map (user: {
      name = user;
      value = {
        default =
          let
            matches = filter (h: h.user == user && h.host == null) homes;
          in
          if matches == [ ] then null else (builtins.head matches).path;
        hosts = listToAttrs (
          map (h: {
            name = h.host;
            value = h.path;
          }) (filter (h: h.user == user && h.host != null) homes)
        );
      };
    }) (lib.unique (map (h: h.user) homes))
  );

  # ---------------------------------------------------------------------------
  # users/
  # ---------------------------------------------------------------------------

  parseUser =
    entry:
    let
      dir = entry.path;
      metaPath = dir + "/meta.nix";
      defaultPath = dir + "/default.nix";
      rawMeta = if pathExists metaPath then metadata.readMeta metaPath else errors.missingFile metaPath;
      meta = metadata.normalizeUserMeta metaPath rawMeta;
      homeHosts =
        let
          value = homesByUser.${entry.name} or { hosts = { }; };
        in
        attrNames value.hosts;
      userHosts = lib.unique (meta.hosts ++ homeHosts);
      validated = map (host: if hostsByName ? ${host} then host else errors.unknownHost host) userHosts;
    in
    if validated == [ ] then
      throw "terminus: users/${entry.name}/meta.nix does not associate the user with any host"
    else
      {
        name = entry.name;
        inherit dir metaPath rawMeta;
        defaultPath = if pathExists defaultPath then defaultPath else null;
        meta = meta // {
          hosts = validated;
        };
        hosts = validated;
      };

  users = map parseUser (listDirsSafe "users");
  usersByName = listToAttrs (
    map (u: {
      name = u.name;
      value = u;
    }) users
  );

  # Every home needs a users/<user>/meta.nix.
  _validateHomeUsers = map (
    h: if usersByName ? ${h.user} then null else errors.unknownUser h.user
  ) homes;

  usersByHost = listToAttrs (
    map (host: {
      name = host;
      value = map (u: u.name) (filter (u: elem host u.hosts) users);
    }) (attrNames hostsByName)
  );

  # ---------------------------------------------------------------------------
  # modules/
  # ---------------------------------------------------------------------------

  modulesRoot = at "modules";

  magicModuleFiles = [
    "options.nix"
    "default.nix"
    "nixos.nix"
    "home.nix"
  ];

  walkModules =
    dir:
    let
      entries = fs.listDir dir;
      here = filter (e: e.type == "regular" && elem e.name magicModuleFiles) entries;
      children = filter (e: e.type == "directory") entries;
      relative = fs.relative modulesRoot dir;
      name = replaceStrings [ "/" ] [ "." ] relative;
      metaPath = dir + "/meta.nix";
      files = listToAttrs (
        map (e: {
          name = lib.removeSuffix ".nix" e.name;
          value = e.path;
        }) here
      );
      sideFiles = names: map (n: files.${n}) (filter (n: files ? ${n}) names);
    in
    (
      if here == [ ] then
        [ ]
      else
        [
          {
            name = if name == "" then "_root" else name;
            path = dir;
            inherit files metaPath;
            meta =
              if pathExists metaPath then
                metadata.normalizeModuleMeta metaPath (metadata.readMeta metaPath)
              else
                metadata.normalizeModuleMeta metaPath { };
            side = {
              nixos = sideFiles [
                "options"
                "default"
                "nixos"
              ];
              home = sideFiles [
                "options"
                "default"
                "home"
              ];
            };
          }
        ]
    )
    ++ concatMap (child: walkModules child.path) children;

  localModules = if pathExists modulesRoot then walkModules modulesRoot else [ ];

  _checkDuplicateModules =
    let
      names = map (m: m.name) localModules;
      dupes = filter (name: length (filter (n: n == name) names) > 1) (lib.unique names);
    in
    if dupes == [ ] then null else errors.duplicate "module" (builtins.head dupes);

  modulesByName = listToAttrs (
    map (m: {
      name = m.name;
      value = m;
    }) localModules
  );

  # ---------------------------------------------------------------------------
  # profiles/
  # ---------------------------------------------------------------------------

  profiles = profilesLib.load { dir = at "profiles"; };

  # ---------------------------------------------------------------------------
  # packages/
  # ---------------------------------------------------------------------------

  packagesRoot = at "packages";

  packageMeta = dir: readOutputMeta dir;

  parsePackageDir =
    entry:
    let
      dir = entry.path;
      defaultPath = dir + "/default.nix";
      meta = packageMeta dir;
    in
    if pathExists defaultPath then
      let
        suffix = lastDotPart entry.name;
        useSuffix = meta.systems == null && suffix != null && knownSystemSet ? ${suffix};
        name =
          if useSuffix then
            lib.concatStringsSep "." (lib.init (lib.splitString "." entry.name))
          else
            entry.name;
      in
      [
        {
          inherit name meta;
          path = defaultPath;
          system = if useSuffix then suffix else null;
        }
      ]
    else
      lib.concatMap (
        sub:
        if !(pathExists (sub.path + "/default.nix")) then
          [ ]
        else
          [
            {
              name = sub.name;
              path = sub.path + "/default.nix";
              system = entry.name;
              meta = packageMeta sub.path;
            }
          ]
      ) (filter (e: e.type == "directory") (fs.listDir dir));

  packages =
    if pathExists packagesRoot then
      lib.concatMap parsePackageDir (filter (e: e.type == "directory") (fs.listDir packagesRoot))
    else
      [ ];

  _checkDuplicatePackages =
    let
      key = p: "${if p.system == null then "*" else p.system}:${p.name}";
      keys = map key packages;
      dupes = filter (k: length (filter (x: x == k) keys) > 1) (lib.unique keys);
    in
    if dupes == [ ] then null else errors.duplicate "package" (builtins.head dupes);

  # ---------------------------------------------------------------------------
  # overlays/, apps/, shells/, checks/, formatter/, lib/
  # ---------------------------------------------------------------------------

  namedOutputs =
    sub:
    if !(pathExists (at sub)) then
      [ ]
    else
      map
        (entry: {
          inherit (entry) name path;
          meta = readOutputMeta entry.path;
        })
        (filter (e: e.type == "directory" && pathExists (e.path + "/default.nix")) (fs.listDir (at sub)));

  overlays = namedOutputs "overlays";
  apps = namedOutputs "apps";
  shells = namedOutputs "shells";
  checks = namedOutputs "checks";

  formatter =
    if pathExists (at "formatter/default.nix") then
      {
        path = at "formatter/default.nix";
        meta = readOutputMeta (at "formatter");
      }
    else
      null;

  libFiles = map (entry: {
    name = lib.removeSuffix ".nix" entry.name;
    path = entry.path;
  }) (nixFilesSafe "lib");

  # ---------------------------------------------------------------------------
  # keys/deploy/
  # ---------------------------------------------------------------------------

  deployKeys =
    if !(pathExists (at "keys/deploy")) then
      [ ]
    else
      lib.unique (
        filter (key: key != "") (
          map (entry: lib.trim (builtins.readFile entry.path)) (
            filter (e: e.type == "regular" && lib.hasSuffix ".pub" e.name) (fs.listDir (at "keys/deploy"))
          )
        )
      );

  # ---------------------------------------------------------------------------
  # report
  # ---------------------------------------------------------------------------

  lastDotPart =
    name:
    let
      parts = lib.splitString "." name;
    in
    if length parts < 2 then null else lib.last parts;
in
lib.deepSeq
  [
    _checkDuplicateModules
    _checkDuplicatePackages
    _validateHomeUsers
  ]
  {
    inherit
      hosts
      hostsByName
      users
      usersByName
      usersByHost
      homes
      homesByUser
      localModules
      modulesByName
      profiles
      packages
      overlays
      apps
      shells
      checks
      formatter
      libFiles
      deployKeys
      ;

    hostNames = attrNames hostsByName;
    moduleNames = attrNames modulesByName;
    userNames = attrNames usersByName;
    profileNames = profiles.names;
  }
