{
  config,
  lib,
  dream2nix,
  ...
}: let
  editables = lib.filterAttrs (_name: path: path != false) config.editables;
in {
  imports = [
    ./interface.nix
    dream2nix.modules.dream2nix.deps
  ];
  deps = {nixpkgs, ...}: {
    inherit (nixpkgs) unzip writeText mkShell;
    python = nixpkgs.python3;
  };
  editables =
    # make root package always editable
    {${config.name} = config.paths.package;};
  editablesShellHook = import ./editable.nix {
    inherit lib;
    inherit (config.deps) unzip writeText;
    inherit (config.paths) findRoot;
    inherit (config) editables pyEnv;
    rootName = config.name;
  };
  editablesDevShell = config.deps.mkShell {
    packages = [config.pyEnv];
    shellHook = config.editablesShellHook;
    buildInputs =
      [(config.drvs.tomli.public or config.deps.python.pkgs.tomli)]
      ++ lib.flatten (
        lib.mapAttrsToList
        (name: _path: config.drvs.${name}.mkDerivation.buildInputs or [])
        editables
      );
    nativeBuildInputs = lib.flatten (
      lib.mapAttrsToList
      (name: _path: config.drvs.${name}.mkDerivation.nativeBuildInputs or [])
      editables
    );
  };
}
