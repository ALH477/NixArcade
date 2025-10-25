# NixOS Arcade Machine

A deterministic, reproducible NixOS configuration for building a retro arcade machine. This setup includes a custom Plymouth boot screen with audio, direct boot into DWM (X11) or Hyprland (Wayland) for a pure kiosk experience, button macros for arcade controls, RetroArch/MAME for emulation, Steam/Lutris for modern gaming, and an interactive CLI installer ISO powered by `dialog`.

Built with flakes for reproducibility and integrated with Determinate Systems tools for faster builds. Licensed under MIT.

## Features
- **Custom Boot Experience**: Plymouth theme with pixel art animation, progress bar, and optional boot jingle (WAV file).
- **Window Manager Options**: Choose DWM (stable X11) or Hyprland (modern Wayland) with auto-login to `arcade` user.
- **Arcade Controls**: Button macros via `xremap` (e.g., joystick to Super+J for window focus). Supports USB joysticks/encoders. New: Button bind for safe shutdown.
- **Gaming Stack**: RetroArch (full) and MAME for emulation. Full-screen startup configurable. Integrated Steam and Lutris for PC games and Wine runners. New: MangoHUD for performance overlays, ProtonUP-Qt for custom Proton, and controller config sync.
- **Installer ISO**: Bootable ISO with a UX-friendly CLI (menus for WM, disk, resolution, swap, etc.). Automated partitioning and flake-based install.
- **Determinism**: Flake-based config with Determinate Systems caching for quick rebuilds.
- **Hardware Support**: Early loading of audio/joystick modules; GRUB resolution options for CRT/HD displays. New: 32-bit OpenGL and PulseAudio for gaming reliability.

## Prerequisites
- NixOS (unstable channel recommended) or Nix on another distro.
- Hardware: x86_64 arcade cabinet (adjust for aarch64/Raspberry Pi). USB joystick or keyboard encoder for buttons.
- Legal ROMs for MAME/RetroArch (not included; source your own).
- Internet for building/installing (fetches packages).

## Quick Start
1. Clone this repo (or copy the `flake.nix` and assets):
   ```
   git clone <your-repo> arcade-nixos
   cd arcade-nixos
   ```
2. Add assets:
   - `./arcade-theme/`: Plymouth theme files (e.g., `background.png`, `script.script`).
   - `./sounds/arcade-jingle.wav`: Short boot audio (public domain recommended).
3. Build the installer ISO:
   ```
   nix build .#installerIso
   ```
   Output: `result/iso/nixos-*-arcade.iso`. Burn to USB.
4. Boot the ISO on your arcade machine and follow the dialog prompts.

## Building and Installation
### Building the ISO
- Run `nix build .#installerIso` to generate a bootable ISO.
- For faster builds with Determinate Systems:
  ```
  nix build .#installerIso --option extra-substituters "https://nix-community.cachix.org" --option extra-trusted-public-keys "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
  ```
- Test in QEMU:
  ```
  qemu-system-x86_64 -cdrom result/iso/nixos-*.iso -m 2G -enable-kvm
  ```

### Installation Process
1. Boot from the ISO (USB/CD).
2. The installer launches automatically:
   - Welcome and WM choice (DWM or Hyprland).
   - GRUB resolution (e.g., 1920x1080 for HD, 800x600 for CRT).
   - Disk selection (lists devices with size/model; validates >8GB).
   - Optional 4GB swap partition.
   - Confirmation (data loss warning; back/cancel options).
   - Automated GPT partitioning (EFI + [swap] + root), formatting, and mounting.
   - Network check and flake install.
   - Hardware check (e.g., joystick module).
   - ROM directory creation (`/home/arcade/roms`).
3. Reboot. System boots to Plymouth splash, plays jingle (post-splash note), auto-logins to DWM/Hyprland, and launches RetroArch. New: Post-reboot dialog for Steam/Lutris setup.

### Post-Install Setup
- **ROMs**: Copy legal ROMs to `/home/arcade/roms`. Configure RetroArch playlists accordingly.
- **Button Testing**: SSH in or use console: `evtest /dev/input/event*` to identify codes, then tweak `services.xremap.config` in `flake.nix`.
- **Auto-Launch Games**: Edit WM config (e.g., Hyprland: `exec-once = retroarch --fullscreen` in `hyprland.conf`).
- **Rebuild System**: From installed system:
  ```
  sudo nixos-rebuild switch --flake /etc/nixos#arcade-dwm  # Or arcade-hyprland
  ```
- **Run Tests**: `nix build .#checks.plymouth-test` or `.#checks.audio-test`.

## Gaming Integration
This setup provides a seamless gaming experience, blending retro emulation with modern PC gaming. RetroArch and MAME handle classic arcade titles, while Steam and Lutris enable native and Wine-based games (e.g., indie titles, older Windows games). A custom launcher script allows switching between them via arcade buttons, maintaining the kiosk feel.

### RetroArch/MAME Setup
- **Packages**: Included via `environment.systemPackages` (RetroArch full build with MAME cores).
- **Configuration**: 
  - ROMs go in `/home/arcade/roms`.
  - Auto-launch on boot: Add to WM startup (e.g., Hyprland: `exec-once = retroarch --fullscreen` in `~/.config/hypr/hyprland.conf`; DWM: Patch `config.h` with `spawn, SHCMD("retroarch --fullscreen")`).
- **Controls**: Use RetroArch's input remapping for arcade buttons, or extend `xremap` for global macros. New: Run `controller-sync` to copy autoconfigs to Lutris.

### Steam Integration
- **Enabled**: Via `programs.steam.enable = true;` (includes 32-bit support, unfree packages allowed).
- **First Run**: Log in via mouse/keyboard (Steam Big Picture mode recommended for arcade use). Download games as needed. New: Post-reboot dialog auto-launches in Big Picture.
- **Performance Tips**: Use MangoHUD (`mangohud steam`) and ProtonUP-Qt for custom Proton versions.

### Lutris Integration
- **Package**: Overridden with extras like Wine, Vulkan, Zenity, and MangoHUD for smooth runner management.
- **Usage**: Launch Lutris to add/install games (e.g., via Wine or Proton). Supports scripts for custom setups. New: Post-reboot dialog auto-launches for setup.
- **Dependencies**: Includes `wineWowPackages.stable`, `vulkan-loader`, and more for compatibility.

### Switching Apps with `arcade-launcher` Script
A bash script (`/run/current-system/sw/bin/arcade-launcher`) closes RetroArch and launches Steam/Lutris on a secondary workspace (tag 2 by default), keeping your retro setup accessible.

- **Usage**:
  ```
  arcade-launcher steam    # Closes RetroArch, switches to WS2, launches Steam
  arcade-launcher lutris   # Same for Lutris
  ```
- **How It Works**:
  - Kills `retroarch` processes.
  - Detects WM (Hyprland: `hyprctl` for dispatch; DWM: `xdotool` for Super+2 keybind).
  - Launches in background.
- **Button Binding**:
  - Extend `services.xremap.config.remap` (e.g., `"BTN_WEST" = "super+shift+s";` for Steam).
  - In Hyprland config (via home-manager): `bind = SUPER SHIFT, S, exec, arcade-launcher steam`.
  - In DWM: Patch `config.h` with `{ MODKEY|ShiftMask, XK_s, spawn, SHCMD("arcade-launcher steam") }`.
- **Customization**: Edit the script in `flake.nix` to change workspace (e.g., `TARGET_WS=3`) or add flags (e.g., `steam -bigpicture`).

### Controller Sync
Run `controller-sync` to copy RetroArch autoconfigs to Lutris (e.g., for unified arcade controls). Add to WM startup if needed.

## Customization
### Flake Structure
- `flake.nix`: Defines `arcade-dwm`, `arcade-hyprland`, and `installerIso`. New: Test checks and home-manager integration.
- `arcade-theme.nix`: Packages Plymouth theme.
- Common modules: Plymouth, audio, xremap, etc.

To customize:
- WM choice: Pass `--arg wmChoice '"hyprland"'` to `nixos-rebuild`.
- Button macros: Edit `services.xremap.config.remap` (use `evtest` for codes). New: BTN_SELECT for poweroff.
- Plymouth: Modify `./arcade-theme/script.script` (visuals only; no audio calls).
- Audio: Replace `./sounds/arcade-jingle.wav` (WAV, <100KB).
- Hardware: Add modules to `boot.initrd.kernelModules` (e.g., `snd_usb_audio` for USB sound).
- User Configs: Edit home-manager.users.arcade for Hyprland binds, .xinitrc, etc.

For Raspberry Pi: Change `system = "aarch64-linux"` and add `nixos-hardware` input.

### Example: Add Custom Resolution
In `commonModules`, set `boot.loader.grub.gfxmode = "1024x768";` or use installer's dynamic prompt.

## Known Issues
- **Steam/Lutris First-Run**: Requires keyboard/mouse for initial login and setup (e.g., Steam account, Lutris runners). Mitigated by post-reboot dialog auto-launch, but hardware input may be needed once.
- **Audio Timing**: Boot jingle may play after Plymouth splash due to ALSA loading. Test with `aplay`; consider custom kernel for earlier init.
- **Controller Detection**: If joysticks fail, run `lsmod | grep joydev` and rebuild. Sync script assumes default dirs; adjust if customized.
- **WM Keybind Conflicts**: DWM xdotool simulation may fail with custom patches; verify config.h.
- **Gaming Compatibility**: Some games need manual Proton tweaks via ProtonUP-Qt. 32-bit titles may require extra libs.

## Troubleshooting
- **Installer Errors**: Check `/tmp/installer.log` in live env. Common: No network (retry DHCP), small disk (<8GB).
- **No Plymouth/Audio**: Verify `quiet splash` in `boot.kernelParams`. Audio may play post-splash (ALSA timing). Test: `aplay /boot/sounds/arcade-jingle.wav`.
- **Button Issues**: Run `evtest`; ensure `joydev` loads. For Wayland, add `withWlroots = true;` in xremap.
- **WM Fails**: Logs: `journalctl -b -u getty@tty1`. Fallback: Enable display manager temporarily.
- **Gaming Issues**: Steam/Lutris: Ensure `allowUnfree = true;`. Lutris deps: Add to `extraLibraries` if errors. Script: Verify WM session type (`echo $XDG_SESSION_TYPE`).
- **Build Fails**: Update inputs: `nix flake update`. Use `--impure` for dev.
- **Joystick Not Detected**: Add `hardware.joystick.enable = true;` to modules.

## Resources
- [NixOS Wiki: Plymouth](https://nixos.wiki/wiki/Plymouth)
- [Hyprland Docs](https://wiki.hyprland.org)
- [RetroArch Setup](https://www.retroarch.com)
- [Determinate Systems](https://determinate.systems)

## License
MIT License. See [LICENSE](LICENSE) for details.

---

*Project built on October 24, 2025. Contributions welcome via PRs!*
