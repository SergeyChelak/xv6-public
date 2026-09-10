# Development shell for xv6 (x86 version).
#
#   nix-shell                 enter the shell (or use direnv: `use nix`)
#   make                      build kernel + disk images into build/
#   make qemu-nox             build and run xv6 in QEMU on the terminal
#                             (quit QEMU with Ctrl-a x)
#   make qemu                 run with a graphical VGA window
#   make qemu-nox-gdb         run with a gdb stub, waiting for a debugger;
#                             then in a second `nix-shell`: gdb -x .gdbinit
#   make clean                remove build products
#
# The kernel and user programs are freestanding 32-bit ELF binaries, so they are
# built with an i686-elf cross toolchain from nixpkgs (pkgsCross.i686-embedded).
# mkfs is a host tool and uses the regular native gcc that mkShell provides.
{ pkgs ? import <nixpkgs> { } }:

let
  cross = pkgs.pkgsCross.i686-embedded.buildPackages;
in
pkgs.mkShell {
  name = "xv6-x86";

  nativeBuildInputs = [
    cross.gcc # i686-elf-gcc, -ld, -objcopy, -objdump (binutils are propagated)
    pkgs.qemu # full build: qemu-system-i386 (its gdb stub speaks 32-bit; the
    #           x86_64 one reports 64-bit registers and breaks `gdb -x .gdbinit`)
    pkgs.gdb # multi-arch gdb; .gdbinit.tmpl switches between i8086/i386
    pkgs.perl # sign.pl and vectors.pl
  ];

  # nixpkgs' compiler wrappers inject PIE, stack protector, fortify, relro, ...
  # None of that works for a bare-metal kernel linked with a custom linker script.
  hardeningDisable = [ "all" ];

  # Picked up by the Makefile (both are `ifndef`-guarded there).
  TOOLPREFIX = "i686-elf-";
  QEMU = "qemu-system-i386";

  shellHook = ''
    echo "xv6 (x86) dev shell: TOOLPREFIX=$TOOLPREFIX QEMU=$QEMU"
    echo "  make qemu-nox      build & run (exit QEMU with Ctrl-a x)"
    echo "  make qemu-nox-gdb  run under gdb stub; then: gdb -x .gdbinit"
  '';
}
