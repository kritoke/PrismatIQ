{ pkgs }:

/*
  Provide a simple module that exposes a `crystal_1_18_2` attribute. We
  currently default to `pkgs.crystal` to avoid fragile fixed-output
  derivations in the repo. If you want to pin a specific binary, replace
  this with a proper `fetchurl` derivation and track the file in Git.
*/

let
  crystal_1_18_2 = pkgs.crystal;
in
{
  inherit crystal_1_18_2;
  buildInputs = [ crystal_1_18_2 ];
}
