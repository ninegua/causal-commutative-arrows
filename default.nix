{ nixpkgs ? import <nixpkgs> {}, compiler ? "default", doBenchmark ? false }:

let

  inherit (nixpkgs) pkgs;

  f = { mkDerivation, array, base, containers, criterion, ghc
      , ghc-prim, HCodecs, mersenne-random-pure64, stdenv
      , template-haskell, transformers, vector
      }:
      mkDerivation {
        pname = "cca";
        version = "0.0.1";
        src = ./.;
        isLibrary = true;
        isExecutable = true;
        libraryHaskellDepends = [
          base containers ghc ghc-prim transformers vector
        ];
        executableHaskellDepends = [
          array base criterion HCodecs mersenne-random-pure64
          template-haskell vector
        ];
        license = stdenv.lib.licenses.mit;
      };

  haskellPackages = if compiler == "default"
                       then pkgs.haskellPackages
                       else pkgs.haskell.packages.${compiler};

  variant = if doBenchmark then pkgs.haskell.lib.doBenchmark else pkgs.lib.id;

  drv = variant (haskellPackages.callPackage f {});

in

  if pkgs.lib.inNixShell then drv.env else drv
