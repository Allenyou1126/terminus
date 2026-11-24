# Collect host-independent values exported by modules via exports.nix.
{ lib }:
let
  inherit (builtins)
    attrNames
    filter
    foldl'
    functionArgs
    hasAttr
    isAttrs
    isFunction
    typeOf
    ;

  errors = import ./errors.nix { inherit lib; };
in
{
  collect =
    {
      discovery,
      inputs,
      self,
    }:
    let
      modules = filter (module: module.files ? exports) discovery.localModules;

      evaluate =
        module:
        let
          value = import module.files.exports;
        in
        if isFunction value then
          value (lib.intersectAttrs (functionArgs value) { inherit lib inputs self; })
        else
          value;

      merge =
        state: module:
        let
          value = evaluate module;
          keys =
            if isAttrs value then attrNames value else errors.invalidModuleExport module.name (typeOf value);
        in
        lib.deepSeq keys (
          foldl' (
            acc: key:
            if hasAttr key acc.sources then
              errors.duplicateExport key acc.sources.${key} module.name
            else
              {
                values = acc.values // {
                  ${key} = value.${key};
                };
                sources = acc.sources // {
                  ${key} = module.name;
                };
              }
          ) state keys
        );

      merged = foldl' merge {
        values = { };
        sources = { };
      } modules;
    in
    merged.values;
}
