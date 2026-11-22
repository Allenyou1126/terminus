# Stable dependency graph validation and topological ordering.
{ lib }:
let
  inherit (builtins)
    attrNames
    concatMap
    elem
    filter
    foldl'
    head
    length
    listToAttrs
    ;

  errors = import ./internal/errors.nix { inherit lib; };

  unique = lib.unique;
in
{
  sort =
    {
      graph,
      enabled,
    }:
    let
      enabledSet = listToAttrs (
        map (name: {
          inherit name;
          value = true;
        }) enabled
      );

      isEnabled = name: enabledSet ? ${name};

      known = name: graph ? ${name};

      validate =
        name:
        let
          meta = graph.${name};
          checkKnown =
            field: ref: if !(known ref) then errors.unknownModule "module reference '${field}'" ref else null;
          checkAll = field: refs: map (checkKnown field) refs;
        in
        (checkAll "requires" meta.requires)
        ++ (checkAll "after" meta.after)
        ++ (checkAll "before" meta.before)
        ++ (checkAll "wants" meta.wants)
        ++ (checkAll "conflicts" meta.conflicts)
        ++ (map (dep: if !(isEnabled dep) then errors.missingDependency name dep else null) meta.requires)
        ++ (map (other: if isEnabled other then errors.moduleConflict name other else null) meta.conflicts);

      edge = from: to: {
        inherit from to;
      };

      requiresEdges = name: map (dep: edge dep name) graph.${name}.requires;

      afterEdges =
        name: map (target: edge target name) (filter (target: isEnabled target) graph.${name}.after);

      beforeEdges =
        name: map (target: edge name target) (filter (target: isEnabled target) graph.${name}.before);

      wantsEdges =
        name: map (target: edge target name) (filter (target: isEnabled target) graph.${name}.wants);

      edges = unique (
        concatMap (
          name: requiresEdges name ++ afterEdges name ++ beforeEdges name ++ wantsEdges name
        ) enabled
      );

      adjacency = listToAttrs (
        map (name: {
          inherit name;
          value = unique (map (e: e.to) (filter (e: e.from == name) edges));
        }) enabled
      );

      indegree = listToAttrs (
        map (name: {
          inherit name;
          value = length (filter (e: e.to == name) edges);
        }) enabled
      );

      step =
        done: degrees:
        let
          available = lib.sort (a: b: a < b) (
            filter (name: !(done ? ${name}) && degrees.${name} == 0) enabled
          );
        in
        if available == [ ] then
          let
            remaining = filter (name: !(done ? ${name})) enabled;
          in
          if remaining == [ ] then [ ] else errors.moduleCycle remaining
        else
          let
            next = head available;
            newDone = done // {
              ${next} = true;
            };
            newDegrees = foldl' (
              acc: target:
              acc
              // {
                ${target} = acc.${target} - 1;
              }
            ) degrees (adjacency.${next} or [ ]);
          in
          [ next ] ++ step newDone newDegrees;
    in
    # `validate` returns a list of nulls and throws on errors; deepSeq makes
    # sure it runs before the sort result is observed.
    lib.deepSeq (map validate enabled) (step { } indegree);
}
