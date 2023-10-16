{
  lib,
  config,
  dream2nix,
  ...
}: {
  imports = [
    dream2nix.modules.dream2nix.nodejs-devshell
    dream2nix.modules.dream2nix.nodejs-package-lock
  ];

  nodejs-package-lock = {
    source = config.deps.fetchFromGitHub {
      owner = "piuccio";
      repo = "cowsay";
      rev = "v1.5.0";
      sha256 = "sha256-TZ3EQGzVptNqK3cNrkLnyP1FzBd81XaszVucEnmBy4Y=";
    };
  };

  deps = {nixpkgs, ...}: {
    inherit
      (nixpkgs)
      fetchFromGitHub
      mkShell
      rsync
      stdenv
      ;
  };

  name = "cowsay";
  version = "1.5.0";

  mkDerivation = {
    src = config.nodejs-package-lock.source;
    # allow devshell to be built -> CI pipeline happy
    buildPhase = "mkdir $out";
  };
}
