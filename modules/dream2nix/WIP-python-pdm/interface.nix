{
  config,
  lib,
  specialArgs,
  ...
}: let
  l = lib // builtins;
  t = l.types;
  mkSubmodule = import ../../../lib/internal/mkSubmodule.nix {inherit lib specialArgs;};
in {
  options.pdm = mkSubmodule {
    imports = [
      ../python-editables
    ];
    options = {
      lockfile = l.mkOption {
        type = t.path;
      };
      pyproject = l.mkOption {
        type = t.path;
      };

      sourceSelector = import ./sourceSelectorOption.nix {inherit lib;};
    };
  };
  options.groups =
    (import ../WIP-groups/groups-option.nix {inherit config lib specialArgs;})
    // {
      internal = true;
      visible = "shallow";
    };
}
