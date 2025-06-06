{
  inputs = {
    nixpkgs.url = "nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        nodeDeps = import ./node-deps.nix { inherit pkgs; };
        inherit (nodeDeps) packageJSON nodeModules;

        pkgs = import nixpkgs {
          inherit system;
        };

        commonBuildInputs = with pkgs; [
          fontconfig
          html-tidy
          sass
          ubuntu-sans
          yarn
        ];

        site = pkgs.stdenv.mkDerivation {
          name = "eleventy-site";
          src = ./.;
          buildInputs = commonBuildInputs ++ [ nodeModules ];

          configurePhase = ''
            ln -sf ${packageJSON} package.json
            ln -sf ${nodeModules}/node_modules .
          '';

          buildPhase = ''
            yarn --offline eleventy
            find _site -name "*.html" -exec tidy --wrap 80 --indent auto --indent-spaces 2  --wrap 80 --quiet yes --tidy-mark no --drop-empty-elements no --custom-tags yes -modify {} \;
          '';

          installPhase = ''cp -r _site $out'';

          # Fix potential permissions issues
          dontFixup = true;
        };

        mkScript =
          name:
          (pkgs.writeScriptBin name (builtins.readFile ./bin/${name})).overrideAttrs (old: {
            buildCommand = "${old.buildCommand}\n patchShebangs $out";
          });

        mkPackage =
          name:
          pkgs.symlinkJoin {
            inherit name;
            paths = [ (mkScript name) ] ++ commonBuildInputs;
            buildInputs = [ pkgs.makeWrapper ];
            postBuild = "wrapProgram $out/bin/${name} --prefix PATH : $out/bin";
          };

        scripts = [
          "build"
          "serve"
          "dryrun"
          "tidy_html"
        ];

        scriptPackages = builtins.listToAttrs (
          map (name: {
            inherit name;
            value = mkPackage name;
          }) scripts
        );
      in
      rec {
        defaultPackage = packages.site;
        packages = scriptPackages // {
          inherit site;
        };

        devShells = rec {
          default = dev;
          dev = pkgs.mkShell {
            buildInputs = commonBuildInputs ++ (map (name: mkPackage name) scripts);
            shellHook = ''
              rm -rf node_modules
              rm -rf package.json
              ln -sf ${packageJSON} package.json
              ln -sf ${nodeModules}/node_modules .
              echo "Development environment ready!"
              echo ""
              echo "Run:"
              echo " - 'serve' to start development server"
              echo " - 'build' to build the site in the _site directory"
              echo " - 'dryrun' to do a dry run"
              echo " - 'tidy_html' to tidy the html in _site"
              echo ""
              git pull
            '';
          };
        };
      }
    );
}
