{ pkgs }:

/*
  Temporarily avoid fetching a specific Crystal tarball which can cause
  fixed-output derivation hash mismatches during evaluation. By default
  fall back to the Crystal package provided by nixpkgs. If you need to pin
  a custom Crystal binary, replace this implementation with a proper
  fetchurl and the correct sha256 (use `nix-prefetch-url --unpack` to obtain
  the sha256 in base32 form).
*/

{ pkgs }:

{
  inherit (pkgs) crystal;
  buildInputs = [ pkgs.crystal ];
}
