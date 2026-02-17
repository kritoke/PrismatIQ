{
  description = "PrismatIQ Spoke - crystal";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    openspec.url = "github:Fission-AI/OpenSpec";
  };

  outputs = { self, nixpkgs, openspec }:
    let
      system = "aarch64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      crystal-1-18-2_mod = import ./nix/modules/crystal-1-18-2.nix { inherit pkgs; };
      # Local package aliases
      let
        crystal_1_18_2 = crystal_1_18_2;
      in

      # System-specific Xorg libraries for Playwright
      # The `xorg` attribute set is deprecated in nixpkgs; prefer modern attribute names.
      # Map legacy names (libX...) to modern names (libx...) and try both.
      getXorg = name:
        let alt = builtins.replaceStrings [ "libX" ] [ "libx" ] name;
        in if builtins.hasAttr alt pkgs then builtins.getAttr alt pkgs else if builtins.hasAttr name pkgs then builtins.getAttr name pkgs else null;

      # Playwright libs removed from default spoke; include only when explicitly requested in a module.
      pwLibs = with pkgs; [];
    in {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [ ] ++ [ crystal-1-18-2_mod.crystal_1_18_2 ] ++ pwLibs;

        # Use a local, untracked `flake.private.nix` to inject any personal shellHook
        # or environment glue. This keeps personal workspace-specific logic out of
        # the repository. If `flake.private.nix` exists it should export a shell
        # snippet; otherwise a minimal shellHook runs.
        private_hook = if builtins.pathExists ./flake.private.nix then builtins.readFile ./flake.private.nix else "";

        shellHook = ''
${private_hook}
echo "PrismatIQ DevShell Active"
'';
      };
    };
}
