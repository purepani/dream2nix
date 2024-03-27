# custom app to update the lock file of each exported package.
{
  self,
  lib,
  inputs,
  ...
}: {
  imports = [
    ./writers.nix
  ];
  perSystem = {
    config,
    self',
    inputs',
    pkgs,
    system,
    ...
  }: let
    l = lib // builtins;

    packages = lib.filterAttrs (name: _: lib.hasPrefix "example-package-" name) self'.checks;

    scripts =
      l.flatten
      (l.mapAttrsToList
        (name: pkg: pkg.config.lock.refresh or [])
        packages);

    update-locks =
      config.writers.writePureShellScript
      (with pkgs; [
        coreutils
        git
        nix
      ])
      (
        "set -x\n"
        + (l.concatStringsSep "/bin/refresh\n" scripts)
        + "/bin/refresh"
      );

    toApp = script: {
      type = "app";
      program = "${script}";
    };
  in {
    apps = l.mapAttrs (_: toApp) {
      inherit
        update-locks
        ;
    };
  };
}
