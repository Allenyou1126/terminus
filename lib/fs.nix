# Sorted filesystem helpers used by discovery.
{ lib }:
let
  inherit (builtins) attrNames readDir;

  entryAt = entries: base: name: {
    inherit name;
    type = entries.${name};
    path = base + "/${name}";
  };

  listDir =
    base:
    let
      entries = readDir base;
      names = lib.sort (a: b: a < b) (attrNames entries);
    in
    map (entryAt entries base) names;

  listDirs = base: lib.filter (e: e.type == "directory") (listDir base);
  listFiles = base: lib.filter (e: e.type == "regular") (listDir base);

  nixFiles = base: lib.filter (e: lib.hasSuffix ".nix" e.name) (listFiles base);

  relative = base: path: lib.removePrefix "${toString base}/" (toString path);

  readIfExists = path: if builtins.pathExists path then builtins.readFile path else null;

  optionalPath = path: if builtins.pathExists path then path else null;

  # Recursively collect regular files below `base`, in stable path order.
  # Symlinks are ignored deliberately: discovery is a pure source scan.
  walkFiles =
    base:
    let
      here = listDir base;
      files = lib.filter (e: e.type == "regular") here;
      dirs = lib.filter (e: e.type == "directory") here;
    in
    files ++ lib.concatMap (d: walkFiles d.path) dirs;
in
{
  inherit
    listDir
    listDirs
    listFiles
    nixFiles
    relative
    readIfExists
    optionalPath
    walkFiles
    ;
  pathExists = builtins.pathExists;
}
