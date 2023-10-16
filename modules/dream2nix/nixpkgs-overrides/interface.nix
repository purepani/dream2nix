{
  config,
  lib,
  ...
}: let
  l = lib // builtins;
  t = l.types;
in {
  options.nixpkgs-overrides = {
    enable =
      (l.mkEnableOption "Whether to copy attributes, except those in `excluded` from nixpkgs")
      // {
        default = true;
      };

    exclude = l.mkOption {
      type = t.listOf t.str;
      description = "Attributes we do not want to copy from nixpkgs";
    };

    from = l.mkOption {
      type = t.nullOr t.package;
      description = "package from which to extract the attributes";
      default = config.deps.python.pkgs.${config.name} or null;
      defaultText = "config.deps.python.pkgs.\${config.name} or null";
    };

    lib.extractOverrideAttrs = l.mkOption {
      type = t.functionTo t.attrs;
      description = ''
        Helper function to extract attrs from nixpkgs to be re-used as overrides.
      '';
      readOnly = true;
    };

    # Extracts derivation args from a nixpkgs python package.
    lib.extractPythonAttrs = l.mkOption {
      type = t.functionTo t.attrs;
      description = ''
        Helper function to extract python attrs from nixpkgs to be re-used as overrides.
      '';
      readOnly = true;
    };
  };
}
