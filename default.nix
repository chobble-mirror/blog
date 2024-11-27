{ pkgs ? import <nixpkgs> {} }:

let
  # Input source files
  src = ./.;
  nodeDeps = import ./node-deps.nix { inherit pkgs; };
  inherit (nodeDeps) packageJSON nodeModules;

in
pkgs.stdenv.mkDerivation {
  name = "blog-chobble-com";

  src = builtins.filterSource
    (path: type: !(builtins.elem (baseNameOf path) [
      "_site"
      "node_modules"
      ".git"
    ]))
    src;

  nativeBuildInputs = with pkgs; [
    cacert
    html-minifier
    lightningcss
    sass
    yarn
  ];

  configurePhase = ''
    export HOME=$TMPDIR
    mkdir -p _site/style

    cp -r ${nodeModules}/node_modules .
    chmod -R +w node_modules
    cp ${packageJSON} package.json
  '';

  buildPhase = ''
    echo 'Building site'
    yarn --offline eleventy

    echo 'Minifying HTML'
    html-minifier --input-dir _site --output-dir _site --collapse-whitespace --file-ext html
  '';

  installPhase = ''
    mkdir -p $out
    cp -r _site/* $out/
    rm -rf node_modules _site package.json
  '';
}