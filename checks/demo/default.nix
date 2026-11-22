{ runCommand, terminus-hello }:
runCommand "terminus-demo-check" { } ''
  ${terminus-hello}/bin/hello > $out
''
