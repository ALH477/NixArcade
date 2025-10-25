{ stdenv }:
stdenv.mkDerivation {
  name = "plymouth-arcade-theme";
  src = ./arcade-theme;
  installPhase = ''
    mkdir -p $out/share/plymouth/themes/arcade-theme
    cp -r * $out/share/plymouth/themes/arcade-theme
  '';
}
