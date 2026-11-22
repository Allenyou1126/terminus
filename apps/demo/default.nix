{ lib, terminus-hello }:
{
  type = "app";
  program = lib.getExe terminus-hello;
  meta.description = "Terminus demo app";
}
