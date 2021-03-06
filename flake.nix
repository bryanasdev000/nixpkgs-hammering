{
  description = "Tool for pointing out issues in Nixpkgs packages";

  inputs = {
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };

    naersk = {
      url = "github:nmattia/naersk";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, flake-compat, naersk, nixpkgs, utils }: utils.lib.eachDefaultSystem (system: let
    pkgs = import nixpkgs { inherit system; };
    naersk-lib = naersk.lib."${system}";
  in rec {

    packages.ast-checks = naersk-lib.buildPackage {
      name = "ast-checks";
      root = ./ast-checks;
    };

    packages.nixpkgs-hammer =
      let
        # Find all of the binaries installed by ast-checks. Note, if this changes
        # in the future to use wrappers or something else that pollute the bin/
        # directory, this logic will have to grow.
        ast-check-names = let
          binContents = builtins.readDir "${packages.ast-checks}/bin";
        in
          pkgs.lib.mapAttrsToList (name: type: assert type == "regular"; name) binContents;
      in
        pkgs.runCommand "nixpkgs-hammer" {
          buildInputs = with pkgs; [
            python3
            makeWrapper
          ];
        } ''
          install -D ${./tools/nixpkgs-hammer} $out/bin/$name
          patchShebangs $out/bin/$name

          wrapProgram "$out/bin/$name" \
              --prefix PATH ":" ${pkgs.lib.makeBinPath [
                # For echo
                pkgs.coreutils
                pkgs.nixUnstable
                packages.ast-checks
              ]} \
              --set AST_CHECK_NAMES ${pkgs.lib.concatStringsSep ":" ast-check-names}
          ln -s ${./overlays} $out/overlays
          ln -s ${./lib} $out/lib
        '';

    defaultPackage = self.packages.${system}.nixpkgs-hammer;

    apps.nixpkgs-hammer = utils.lib.mkApp { drv = self.packages.${system}.nixpkgs-hammer; };

    defaultApp = self.apps.${system}.nixpkgs-hammer;

    devShell = pkgs.mkShell {
      buildInputs = with pkgs; [
        python3
        rustc
        cargo
      ];
    };
  });
}
