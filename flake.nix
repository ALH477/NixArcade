# Copyright (c) 2025 DeMoD LLC
#
# Permission is hereby granted, free of charge, to any person obtaining a copy...
# (full MIT text, or just "Licensed under the MIT License. See LICENSE for details.")

{
  description = "NixArcade: The Arcade-Focused NixOS Distro from DeMoD LLC";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    determinate.url = "github:DeterminateSystems/nix-installer";
    flake-utils.url = "github:numtide/flake-utils";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, determinate, flake-utils, home-manager, ... }@inputs:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs { inherit system; };
      commonModules = [
        home-manager.nixosModules.home-manager
        {
          # Hardware options for gaming reliability
          hardware.opengl.driSupport32Bit = true;  # 32-bit OpenGL for games
          hardware.pulseaudio.enable = true;  # Reliable audio server
          hardware.pulseaudio.configFile = pkgs.writeText "default.pa" ''
            load-module module-alsa-sink
            load-module module-alsa-source device=hw:0,0
            load-module module-native-protocol-unix
            .nofail
            load-module module-always-sink
            .fail
          '';  # Optional: Fix glitches as per wiki

          # Plymouth, audio, etc. (from previous)
          boot.plymouth = { enable = true; theme = "arcade-theme"; themePackages = [ (pkgs.callPackage ./arcade-theme.nix {}) ]; };
          boot.kernelParams = [ "quiet" "splash" "plymouth:debug" ];
          systemd.services.boot-sound = {
            description = "Play arcade boot sound";
            wantedBy = [ "multi-user.target" ];
            after = [ "plymouth-start.service" "sound.target" ];
            before = [ "display-manager.service" ];
            serviceConfig = {
              Type = "oneshot";
              ExecStart = "${pkgs.alsa-utils}/bin/aplay /boot/sounds/arcade-jingle.wav";
              RemainAfterExit = true;
            };
          };
          sound.enable = true;
          boot.initrd.kernelModules = [ "snd_hda_intel" "hid_generic" "joydev" ];

          # Enable Steam (handles 32-bit support, unfree allowance, etc.)
          programs.steam = {
            enable = true;
          };

          # Allow unfree packages for Steam/Lutris
          nixpkgs.config.allowUnfree = true;

          # Arcade packages and kiosk mode
          environment.systemPackages = with pkgs; [
            retroarchFull mame alsa-utils xremap joy2key evtest
            mangohud  # Performance overlays
            protonup-qt  # Custom Proton management
            wmctrl xdotool dialog
            (lutris.override {
              extraLibraries = pkgs: [
                pkgs.libGL pkgs.vulkan-loader pkgs.vulkan-tools pkgs.wineWowPackages.stable pkgs.winetricks
                pkgs.gnome.zenity pkgs.libgpg-error pkgs.gnutls pkgs.openldap pkgs.libjpeg pkgs.sqlite
              ];
              extraPkgs = pkgs: [ pkgs.mangohud ];
            })
            # arcade-launcher script
            (pkgs.writeShellScriptBin "arcade-launcher" ''
              #!/usr/bin/env bash
              set -e

              APP="$1"  # steam or lutris
              if [ -z "$APP" ]; then
                echo "Usage: $0 [steam|lutris]"
                exit 1
              fi

              # Close RetroArch setup
              pkill -f retroarch || true  # Ignore if not running

              # Target workspace/tag 2 (adjust if needed)
              TARGET_WS=2

              if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
                # Hyprland: Use hyprctl for workspace switch and exec
                hyprctl --batch "dispatch workspace $TARGET_WS ; dispatch exec $APP"
              else
                # DWM/X11: Simulate Super + 2 keybind to switch tag, then launch
                xdotool key super+$TARGET_WS
                $APP &
              fi

              echo "$APP launched on workspace $TARGET_WS."
            '')
            # Controller sync script
            (pkgs.writeShellScriptBin "controller-sync" ''
              #!/usr/bin/env bash
              set -e
              RETROARCH_AUTOCONFIG="$HOME/.config/retroarch/autoconfig"
              LUTRIS_CONTROLLERS="$HOME/.config/lutris/controllers"
              mkdir -p "$LUTRIS_CONTROLLERS"
              cp -r "$RETROARCH_AUTOCONFIG"/* "$LUTRIS_CONTROLLERS/" || echo "No configs to sync."
              echo "Controller configs synced from RetroArch to Lutris."
            '')
          ];
          services.getty.autologinUser = "arcade";

          # Button mapping (extended for shutdown)
          services.xremap = {
            enable = true;
            withWlroots = true;
            config = {
              modmap = [
                {
                  name = "Arcade Macros";
                  remap = {
                    "BTN_SOUTH" = "super+j";
                    "BTN_EAST" = "super+space";
                    "ABS_HAT0Y-up" = "up";
                    "BTN_WEST" = "super+shift+s";  # Steam
                    "BTN_NORTH" = "super+shift+l";  # Lutris
                    "BTN_SELECT" = "super+shift+p";  # Poweroff
                  };
                }
              ];
            };
          };

          # Disable display manager for pure setup
          services.xserver.displayManager.enable = false;
          services.xserver.desktopManager.enable = false;

          # User config with home-manager
          users.users.arcade = {
            isNormalUser = true;
            extraGroups = [ "wheel" "input" "video" ];
            shell = pkgs.zsh;
          };

          # Sample home-manager module
          home-manager.users.arcade = { pkgs, ... }: {
            home.packages = [ pkgs.retroarch ];
            # Example Hyprland config (if Hyprland enabled)
            wayland.windowManager.hyprland = {
              enable = true;
              extraConfig = ''
                bind = SUPER SHIFT, S, exec, arcade-launcher steam
                bind = SUPER SHIFT, L, exec, arcade-launcher lutris
                bind = SUPER SHIFT, P, exec, systemctl poweroff  # Shutdown bind
                exec-once = retroarch --fullscreen  # Auto-launch RetroArch
              '';
            };
            # For DWM: You'd patch config.h separately, but home can manage files
            home.file.".xinitrc".text = ''
              #!/bin/sh
              exec dwm  # Add spawn commands in config.h for binds
            '';
          };

          # Post-reboot dialog service for Steam/Lutris setup
          systemd.user.services.steam-lutris-setup = {
            description = "Initial Steam/Lutris Setup Dialog";
            wantedBy = [ "graphical-session.target" ];
            serviceConfig = {
              Type = "oneshot";
              ExecStart = pkgs.writeShellScript "setup-dialog.sh" ''
                #!/usr/bin/env bash
                if [ ! -f "$HOME/.setup-done" ]; then
                  dialog --title "Gaming Setup" --yesno "Launch Steam in Big Picture mode and Lutris for initial setup?" 8 60 && {
                    steam -bigpicture &
                    lutris &
                  }
                  touch "$HOME/.setup-done"
                fi
              '';
            };
          };
        }
        determinate.nixosModules.default
      ];
    in {
      nixosConfigurations = {
        arcade-dwm = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = commonModules ++ [
            {
              services.xserver.enable = true;
              services.xserver.windowManager.dwm.enable = true;
              environment.systemPackages = with pkgs; [ dwm ];
            }
          ];
        };

        arcade-hyprland = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = commonModules ++ [
            {
              programs.hyprland.enable = true;
              environment.systemPackages = with pkgs; [ hyprland ];
            }
          ];
        };
      };

      # Test suite (nixosTests)
      checks = {
        plymouth-test = nixpkgs.lib.nixosTest {
          name = "plymouth-test";
          nodes.machine = { ... }: {
            boot.plymouth.enable = true;
          };
          testScript = ''
            machine.wait_for_unit("plymouth-start.service")
            machine.succeed("plymouth --show-splash")
          '';
        };
        audio-test = nixpkgs.lib.nixosTest {
          name = "audio-test";
          nodes.machine = { ... }: {
            sound.enable = true;
            hardware.pulseaudio.enable = true;
          };
          testScript = ''
            machine.wait_for_unit("pulseaudio.service")
            machine.succeed("aplay -l")  # List audio devices
          '';
        };
      };

      packages.installerIso = (import "${nixpkgs}/nixos" {
        configuration = {
          imports = [
            "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
            {
              # ... (installer config as in previous messages, with updates)
              networking.useDHCP = true;
              environment.systemPackages = with pkgs; [ dialog git parted lsblk evtest ];
              # Copy flake source, including theme/audio assets
              system.activationScripts.copyFlake.text = ''
                mkdir -p /root/arcade-flake
                cp -r ${self}/* /root/arcade-flake/
                chown -R root:root /root/arcade-flake
              '';
              # Systemd service for installer (as before, with improved script)
              systemd.services.arcade-installer = {
                # ... (full script as in last flake update)
              };
            }
          ];
        };
      }).config.system.build.isoImage;
    });
}
