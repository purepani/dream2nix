{
  config,
  lib,
  dream2nix,
  ...
}: let
  l = lib // builtins;

  cfg = config.rust-crane;

  dreamLock = config.rust-cargo-lock.dreamLock;

  sourceRoot = config.mkDerivation.src;

  fetchDreamLockSources =
    import ../../../lib/internal/fetchDreamLockSources.nix
    {inherit lib;};
  getDreamLockSource = import ../../../lib/internal/getDreamLockSource.nix {inherit lib;};
  readDreamLock = import ../../../lib/internal/readDreamLock.nix {inherit lib;};
  hashPath = import ../../../lib/internal/hashPath.nix {
    inherit lib;
    inherit (config.deps) runCommandLocal nix;
  };
  hashFile = import ../../../lib/internal/hashFile.nix {
    inherit lib;
    inherit (config.deps) runCommandLocal nix;
  };

  # fetchers
  fetchers = {
    git = import ../../../lib/internal/fetchers/git {
      inherit hashPath;
      inherit (config.deps) fetchgit;
    };
    crates-io = import ../../../lib/internal/fetchers/crates-io {
      inherit hashFile;
      inherit (config.deps) fetchurl runCommandLocal;
    };
    path = import ../../../lib/internal/fetchers/path {
      inherit hashPath;
    };
  };

  dreamLockLoaded = readDreamLock {inherit dreamLock;};
  dreamLockInterface = dreamLockLoaded.interface;

  inherit (dreamLockInterface) defaultPackageName defaultPackageVersion;

  fetchedSources' = fetchDreamLockSources {
    inherit defaultPackageName defaultPackageVersion;
    inherit (dreamLockLoaded.lock) sources;
    inherit fetchers;
  };

  fetchedSources =
    fetchedSources'
    // {
      ${defaultPackageName}.${defaultPackageVersion} = sourceRoot;
    };

  getSource = getDreamLockSource fetchedSources;

  toTOML = import ../../../lib/internal/toTOML.nix {inherit lib;};

  utils = import ./utils.nix {
    inherit dreamLock getSource lib toTOML sourceRoot;
    inherit
      (dreamLockInterface)
      getSourceSpec
      getRoot
      subsystemAttrs
      packages
      ;
    inherit
      (config.deps)
      writeText
      ;
  };

  crane = import ./crane.nix {
    inherit lib;
    inherit
      (config.deps)
      stdenv
      cargo
      craneSource
      jq
      zstd
      remarshal
      makeSetupHook
      writeText
      runCommand
      darwin
      ;
  };

  vendoring = import ./vendor.nix {
    inherit dreamLock getSource lib;
    inherit
      (dreamLockInterface)
      getSourceSpec
      subsystemAttrs
      ;
    inherit
      (config.deps)
      cargo
      jq
      moreutils
      python3Packages
      runCommandLocal
      writePython3
      ;
  };

  pname = config.name;
  version = config.version;

  replacePaths =
    utils.replaceRelativePathsWithAbsolute
    dreamLockInterface.subsystemAttrs.relPathReplacements.${pname}.${version};
  writeGitVendorEntries = vendoring.writeGitVendorEntries "nix-sources";

  # common args we use for both buildDepsOnly and buildPackage
  common = {
    src = lib.mkForce (utils.getRootSource pname version);
    postUnpack = ''
      export CARGO_HOME=$(pwd)/.cargo_home
      export cargoVendorDir="$TMPDIR/nix-vendor"
    '';
    preConfigure = ''
      ${writeGitVendorEntries}
      ${replacePaths}
    '';
    inherit pname version;

    cargoVendorDir = "$TMPDIR/nix-vendor";
    installCargoArtifactsMode = "use-zstd";

    cargoBuildProfile = cfg.buildProfile;
    cargoTestProfile = cfg.testProfile;
    cargoBuildFlags = cfg.buildFlags;
    cargoTestFlags = cfg.testFlags;
    doCheck = cfg.runTests;

    # Make sure cargo only builds & tests the package we want
    cargoBuildCommand = "cargo build \${cargoBuildFlags:-} --profile \${cargoBuildProfile} --package ${pname}";
    cargoTestCommand = "cargo test \${cargoTestFlags:-} --profile \${cargoTestProfile} --package ${pname}";
  };

  # The deps-only derivation will use this as a prefix to the `pname`
  depsNameSuffix = "-deps";
  depsArgs = {
    preUnpack = ''
      ${vendoring.copyVendorDir "$dream2nixVendorDir" common.cargoVendorDir}
    '';
    # move the vendored dependencies folder to $out for main derivation to use
    postInstall = ''
      mv $TMPDIR/nix-vendor $out/nix-vendor
    '';
    # we pass cargoLock path to buildDepsOnly
    # so that crane's mkDummySrc adds it to the dummy source
    inherit (utils) cargoLock;
    pname = l.mkOverride 99 pname;
    pnameSuffix = depsNameSuffix;
    # Make sure cargo only checks the package we want
    cargoCheckCommand = "cargo check \${cargoBuildFlags:-} --profile \${cargoBuildProfile} --package ${pname}";
    dream2nixVendorDir = vendoring.vendoredDependencies;
  };

  buildArgs = {
    # link the vendor dir we used earlier to the correct place
    preUnpack = ''
      ${vendoring.copyVendorDir "$cargoArtifacts/nix-vendor" common.cargoVendorDir}
    '';
    # write our cargo lock
    # note: we don't do this in buildDepsOnly since
    # that uses a cargoLock argument instead
    preConfigure = l.mkForce ''
      ${common.preConfigure}
      ${utils.writeCargoLock}
    '';
    cargoArtifacts = cfg.depsDrv.public;
  };
in {
  imports = [
    ./interface.nix
    dream2nix.modules.dream2nix.mkDerivation
    dream2nix.modules.dream2nix.core
  ];

  rust-crane.depsDrv = {
    inherit version;
    name = pname + depsNameSuffix;
    package-func.func = config.deps.crane.buildDepsOnly;
    package-func.args = l.mkMerge [
      common
      depsArgs
    ];
  };

  package-func.func = config.deps.crane.buildPackage;
  package-func.args = l.mkMerge [common buildArgs];

  public = {
    devShell = import ./devshell.nix {
      name = "${pname}-devshell";
      depsDrv = cfg.depsDrv.public;
      mainDrv = config.public;
      inherit lib;
      inherit (config.deps) libiconv mkShell cargo;
    };
    dependencies = cfg.depsDrv.public;
    meta = (utils.getMeta pname version) // config.mkDerivation.meta;
  };

  deps = {nixpkgs, ...}:
    l.mkMerge [
      (l.mapAttrs (_: l.mkDefault) {
        inherit crane;
        cargo = nixpkgs.cargo;
        craneSource = config.deps.fetchFromGitHub {
          owner = "ipetkov";
          repo = "crane";
          rev = "v0.15.0";
          sha256 = "sha256-xpW3VFUG7yE6UE6Wl0dhqencuENSkV7qpnpe9I8VbPw=";
        };
      })
      # maybe it would be better to put these under `options.rust-crane.deps` instead of this `deps`
      # since it conflicts with a lot of stuff?
      (l.mapAttrs (_: l.mkOverride 999) {
        inherit
          (nixpkgs)
          stdenv
          fetchurl
          jq
          zstd
          remarshal
          moreutils
          python3Packages
          makeSetupHook
          runCommandLocal
          runCommand
          writeText
          fetchFromGitHub
          libiconv
          mkShell
          ;
        inherit
          (nixpkgs.pkgsBuildBuild)
          darwin
          ;
        inherit
          (nixpkgs.writers)
          writePython3
          ;
      })
    ];
}
