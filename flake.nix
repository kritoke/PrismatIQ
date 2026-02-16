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

        shellHook = ''
          # --- Common Spoke Setup ---
          export HUB_ROOT="/workspaces/aiworkflow"
          # Ensure SSH agent is available inside the devShell:
          # Try a list of candidate sockets and pick the first responsive agent. This handles
          # cases where the editor or host provides an agent via a symlink or under /run/user.
          HUB_SOCK_CANDIDATES=()
          # Candidate 1: current environment
          if [ -n "$SSH_AUTH_SOCK" ] && [ -S "$SSH_AUTH_SOCK" ]; then
            HUB_SOCK_CANDIDATES+=("$SSH_AUTH_SOCK")
          fi
          # Candidate 2: hub-local symlink
          if [ -S "/workspaces/aiworkflow/.ssh-auth.sock" ]; then
            HUB_SOCK_CANDIDATES+=("/workspaces/aiworkflow/.ssh-auth.sock")
          fi
          # Candidate 3: workspace-level standard path
          if [ -S "/workspaces/.ssh-auth.sock" ]; then
            HUB_SOCK_CANDIDATES+=("/workspaces/.ssh-auth.sock")
          fi
          # Candidate 4: resolve symlink target of SSH_AUTH_SOCK (if present)
          if [ -n "$SSH_AUTH_SOCK" ]; then
            _real=$(readlink -f "$SSH_AUTH_SOCK" 2>/dev/null || true)
            if [ -n "$_real" ] && [ -S "$_real" ]; then
              HUB_SOCK_CANDIDATES+=("$_real")
            fi
          fi
          # Candidate 5: VSCode agent proxy sockets under /run/user
          for s in /run/user/$(id -u)/vscode-ssh-auth-sock-*; do
            if [ -S "$s" ]; then
              HUB_SOCK_CANDIDATES+=("$s")
            fi
          done
          
            # Try the external helper to pick and link a responsive socket (preferred).
            if command -v "/workspaces/aiworkflow/../bin/refresh-ssh-sock" >/dev/null 2>&1; then
              # call helper with HUB_ROOT expanded
              _sock_path=$(HUB_ROOT="/workspaces/aiworkflow" "/workspaces/aiworkflow/../bin/refresh-ssh-sock" 2>/dev/null || true)
              if [ -n "$_sock_path" ] && [ -S "$_sock_path" ]; then
                export SSH_AUTH_SOCK="$_sock_path"
              fi
            else
              # Try candidates in order and pick the first responsive agent
              for cand in "${HUB_SOCK_CANDIDATES[@]:-}"; do
                if [ -S "$cand" ]; then
                  SSH_AUTH_SOCK="$cand" ssh-add -l >/dev/null 2>&1 && {
                    mkdir -p "/workspaces/aiworkflow" 2>/dev/null || true
                    ln -sf "$cand" "/workspaces/aiworkflow/.ssh-auth.sock" || true
                    export SSH_AUTH_SOCK="/workspaces/aiworkflow/.ssh-auth.sock"
                    break
                  }
                fi
              done
          
              # If no responsive agent found, but a hub symlink exists, use it as a fallback
              if [ -S "/workspaces/aiworkflow/.ssh-auth.sock" ] && [ -z "$SSH_AUTH_SOCK" ]; then
                export SSH_AUTH_SOCK="/workspaces/aiworkflow/.ssh-auth.sock"
              fi
            fi
          export PATH="$PATH:$HUB_ROOT/bin"
          export OPEN_SPEC_SKILLS_PATH="$HUB_ROOT/skills"
          export OPEN_SPEC_PROJECT_DIR="/workspaces/PrismatIQ"
          
          echo "PrismatIQ DevShell Active"
         '';
      };
    };
}
