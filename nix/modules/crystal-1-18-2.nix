{ pkgs }:

let
  # Special pinned Crystal 1.18.2 derivation used as the default for spokes.
  crystal_1_18_2 = pkgs.stdenv.mkDerivation rec {
    pname = "crystal";
    version = "1.18.2";

    src = pkgs.fetchurl {
      url = "https://github.com/crystal-lang/crystal/releases/download/${version}/crystal-${version}-1-linux-aarch64.tar.gz";
      # SHA256 obtained via `nix-prefetch-url --unpack` on the Crystal 1.18.2 tarball
      sha256 = "1dzyayqy45kkgh0jdwmb8fmlxgpxwag4c3mhx36sd5vzf4lg7d7w";
    };

    installPhase = ''
      mkdir -p $out
      cp -r ./* $out/
    '';
  };
in
{
  inherit crystal_1_18_2;
  buildInputs = [ crystal_1_18_2 ];
}
