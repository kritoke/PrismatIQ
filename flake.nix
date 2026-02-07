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

      # System-specific Xorg libraries for Playwright
      getXorg = name: if builtins.hasAttr name pkgs.xorg then pkgs.xorg.${name} else null;

      pwLibs = with pkgs; [
        nspr nss atk dbus expat at-spi2-core glib mesa libxkbcommon 
        systemd alsa-lib cairo pango cups libdrm libgbm gtk3 gtk4 
        gdk-pixbuf fontconfig freetype libxshmfence libvpx x264 
        libavif libsecret libwebp libxml2 libxslt libopus harfbuzz 
        libjpeg_turbo lcms2 flite libepoxy libatomic_ops hyphen enchant_2
        gst_all_1.gstreamer gst_all_1.gst-plugins-base 
        gst_all_1.gst-plugins-good gst_all_1.gst-plugins-bad gst_all_1.gst-libav
        (getXorg "libX11") (getXorg "libXcomposite") (getXorg "libXdamage")
        (getXorg "libXext") (getXorg "libXfixes") (getXorg "libXrandr")
        (getXorg "libxcb") (getXorg "libXcursor") (getXorg "libXi") (getXorg "libXrender")
      ];
    in {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [ ] ++ pwLibs;

        shellHook = ''
          
          # --- Common Spoke Setup ---
          export HUB_ROOT="/workspaces/aiworkflow"\\nexport SSH_AUTH_SOCK="$HUB_ROOT/.ssh-auth.sock"\\nexport PATH="$PATH:$HUB_ROOT/bin"\\nexport OPEN_SPEC_SKILLS_PATH="$HUB_ROOT/skills"\\nexport OPEN_SPEC_PROJECT_DIR="/workspaces/PrismatIQ"\\n\\necho "🚀 PrismatIQ DevShell Active"
        '';
      };
    };
}
