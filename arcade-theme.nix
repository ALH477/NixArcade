# Copyright (c) 2025 DeMoD LLC
#
# Permission is hereby granted, free of charge, to any person obtaining a copy...
# (full MIT text, or just "Licensed under the MIT License. See LICENSE for details.")
{ stdenv }:
stdenv.mkDerivation {
  name = "plymouth-arcade-theme";
  src = ./arcade-theme;
  installPhase = ''
    mkdir -p $out/share/plymouth/themes/arcade-theme
    cp -r * $out/share/plymouth/themes/arcade-theme
  '';
}
