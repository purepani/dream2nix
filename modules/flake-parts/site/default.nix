{
  inputs,
  self,
  ...
}: {
  perSystem = {
    config,
    self',
    inputs',
    pkgs,
    lib,
    ...
  }: {
    /*
    Check the links, including anchors (not currently supported by mdbook)

    Putting this in a separate check has the benefits that
     - output can always be inspect with browser
     - this slow check (1 minute) is not part of the iteration cycle

    Ideally https://github.com/linkchecker/linkchecker/pull/661 is merged
    upstream, so that it's quick and can run often without blocking the
    iteration cycle unnecessarily.
    */
    # checks.linkcheck =
    #   pkgs.runCommand "linkcheck"
    #   {
    #     nativeBuildInputs = [pkgs.linkchecker pkgs.python3];
    #     site = config.packages.website;
    #   } ''
    #     # https://linkchecker.github.io/linkchecker/man/linkcheckerrc.html
    #     cat >>$TMPDIR/linkcheckrc <<EOF
    #     [checking]
    #     threads=100

    #     [AnchorCheck]

    #     EOF

    #     echo Checking $site
    #     linkchecker -f $TMPDIR/linkcheckrc $site/

    #     touch $out
    #   '';

    packages = {
      website = pkgs.stdenvNoCC.mkDerivation {
        name = "website";
        nativeBuildInputs = [pkgs.mdbook pkgs.mdbook-linkcheck];
        src = ./.;
        buildPhase = ''
          runHook preBuild

          rm ./src/intro.md
          cp ${self + /README.md} ./src/intro.md
          cat ${self'.packages.generated-summary-md} >> ./src/SUMMARY.md
          mkdir -p ./theme
          cp ${self + /modules/dream2nix/core/docs/theme/favicon.png} ./theme/favicon.png

          mkdir -p src/options
          for f in ${config.packages.generated-docs}/*.html; do
            cp "$f" "src/options/$(basename "$f" .html).md"
          done
          mdbook build --dest-dir $TMPDIR/out
          cp -r $TMPDIR/out/html $out
          cp _redirects $out

          # TODO: point to something else than public.html
          echo '<html><head><script>window.location.pathname = window.location.pathname.replace(/options.html$/, "") + "options/public.html"</script></head><body><a href="options/public.html">to the options</a></body></html>' \
            >$out/options.html

          runHook postBuild
        '';
        dontInstall = true;
      };
    };
  };
}
