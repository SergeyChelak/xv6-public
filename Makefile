# xv6 (x86) build.
#
# Source tree:
#   boot/     boot sector (bootasm.S, bootmain.c) and sign.pl, which pads it
#   common/   headers shared by boot/, kernel/, user/ and mkfs/: basic types,
#             memory layout, MMU/ELF/x86 definitions, the syscall ABI
#             (syscall.h, traps.h, stat.h, fcntl.h) and the on-disk format (fs.h)
#   kernel/   the kernel, its private headers, kernel.ld and vectors.pl
#   user/     user programs, the user library (ulib.c, usys.S, printf.c,
#             umalloc.c, user.h) and initcode.S, the first user program
#   mkfs/     host tool that builds the file system image
#   tools/    developer helpers (gdb macros, panic decoder, ...)
#   doc/      notes and the machinery behind `make print`
#
# All build products are written to $(B), mirroring the source tree:
#   $(B)/boot/bootblock  $(B)/kernel/kernel  $(B)/user/_cat ...
#   $(B)/mkfs/mkfs       $(B)/fs.img         $(B)/xv6.img
# Override with e.g. `make B=out`.
B ?= build
K = kernel
U = user

KOBJS = \
	bio.o\
	console.o\
	exec.o\
	file.o\
	fs.o\
	ide.o\
	ioapic.o\
	kalloc.o\
	kbd.o\
	lapic.o\
	log.o\
	main.o\
	mp.o\
	picirq.o\
	pipe.o\
	proc.o\
	sleeplock.o\
	spinlock.o\
	string.o\
	swtch.o\
	syscall.o\
	sysfile.o\
	sysproc.o\
	trapasm.o\
	trap.o\
	uart.o\
	vectors.o\
	vm.o\

OBJS = $(addprefix $(B)/$K/,$(KOBJS))

# Cross-compiling (e.g., on Mac OS X)
# TOOLPREFIX = i386-jos-elf

# Using native tools (e.g., on X86 Linux)
#TOOLPREFIX = 

# Try to infer the correct TOOLPREFIX if not set
ifndef TOOLPREFIX
TOOLPREFIX := $(shell if i386-jos-elf-objdump -i 2>&1 | grep '^elf32-i386$$' >/dev/null 2>&1; \
	then echo 'i386-jos-elf-'; \
	elif objdump -i 2>&1 | grep 'elf32-i386' >/dev/null 2>&1; \
	then echo ''; \
	else echo "***" 1>&2; \
	echo "*** Error: Couldn't find an i386-*-elf version of GCC/binutils." 1>&2; \
	echo "*** Is the directory with i386-jos-elf-gcc in your PATH?" 1>&2; \
	echo "*** If your i386-*-elf toolchain is installed with a command" 1>&2; \
	echo "*** prefix other than 'i386-jos-elf-', set your TOOLPREFIX" 1>&2; \
	echo "*** environment variable to that prefix and run 'make' again." 1>&2; \
	echo "*** To turn off this error, run 'gmake TOOLPREFIX= ...'." 1>&2; \
	echo "***" 1>&2; exit 1; fi)
endif

# If the makefile can't find QEMU, specify its path here
# QEMU = qemu-system-i386

# Try to infer the correct QEMU
ifndef QEMU
QEMU = $(shell if which qemu > /dev/null; \
	then echo qemu; exit; \
	elif which qemu-system-i386 > /dev/null; \
	then echo qemu-system-i386; exit; \
	elif which qemu-system-x86_64 > /dev/null; \
	then echo qemu-system-x86_64; exit; \
	else \
	qemu=/Applications/Q.app/Contents/MacOS/i386-softmmu.app/Contents/MacOS/i386-softmmu; \
	if test -x $$qemu; then echo $$qemu; exit; fi; fi; \
	echo "***" 1>&2; \
	echo "*** Error: Couldn't find a working QEMU executable." 1>&2; \
	echo "*** Is the directory containing the qemu binary in your PATH" 1>&2; \
	echo "*** or have you tried setting the QEMU variable in Makefile?" 1>&2; \
	echo "***" 1>&2; exit 1)
endif

CC = $(TOOLPREFIX)gcc
AS = $(TOOLPREFIX)gas
LD = $(TOOLPREFIX)ld
OBJCOPY = $(TOOLPREFIX)objcopy
OBJDUMP = $(TOOLPREFIX)objdump
CFLAGS = -fno-pic -static -fno-builtin -fno-strict-aliasing -O2 -Wall -MD -ggdb -m32 -Werror -fno-omit-frame-pointer
CFLAGS += $(shell $(CC) -fno-stack-protector -E -x c /dev/null >/dev/null 2>&1 && echo -fno-stack-protector)
# xv6 never enables SSE (CR4.OSFXSR), so an SSE instruction faults before the
# IDT exists and the machine resets. Native x86-64 compilers default to
# -march=x86-64 (SSE2 on) even with -m32, and gcc >= 12 vectorizes at -O2.
CFLAGS += -mno-sse -mno-mmx
ASFLAGS = -m32 -gdwarf-2 -Wa,-divide
# Shared headers are always named by path ("common/types.h"); kernel-private
# ones are found next to the kernel sources ("defs.h").
CFLAGS += -I.
ASFLAGS += -I.
# FreeBSD ld wants ``elf_i386_fbsd''
LDFLAGS += -m $(shell $(LD) -V | grep elf_i386 2>/dev/null | head -n 1)
# binutils >= 2.39 warns about RWX segments; xv6 links its flat images that way on purpose.
LDFLAGS += $(shell $(LD) --no-warn-rwx-segments --version >/dev/null 2>&1 && echo --no-warn-rwx-segments)

# Disable PIE when possible (for Ubuntu 16.10 toolchain)
ifneq ($(shell $(CC) -dumpspecs 2>/dev/null | grep -e '[^f]no-pie'),)
CFLAGS += -fno-pie -no-pie
endif
ifneq ($(shell $(CC) -dumpspecs 2>/dev/null | grep -e '[^f]nopie'),)
CFLAGS += -fno-pie -nopie
endif

# Newer GCC (>= 12) reports false positives that -Werror would turn fatal:
#  -Warray-bounds       physical<->virtual address arithmetic (P2V() in mp.c)
#  -Winfinite-recursion runcmd() in sh.c never returns (it calls exit())
CFLAGS += -Wno-array-bounds -Wno-infinite-recursion

all: $(B)/xv6.img

# Short names for the main products in $(B).
bootblock: $(B)/boot/bootblock
kernel: $(B)/$K/kernel
kernelmemfs: $(B)/$K/kernelmemfs
mkfs: $(B)/mkfs/mkfs
fs.img: $(B)/fs.img
xv6.img: $(B)/xv6.img
xv6memfs.img: $(B)/xv6memfs.img
.PHONY: all bootblock kernel kernelmemfs mkfs fs.img xv6.img xv6memfs.img

BUILDDIRS = $(B) $(B)/boot $(B)/$K $(B)/$U $(B)/mkfs
$(BUILDDIRS):
	mkdir -p $@

$(B)/xv6.img: $(B)/boot/bootblock $(B)/$K/kernel
	dd if=/dev/zero of=$@ count=10000
	dd if=$(B)/boot/bootblock of=$@ conv=notrunc
	dd if=$(B)/$K/kernel of=$@ seek=1 conv=notrunc

$(B)/xv6memfs.img: $(B)/boot/bootblock $(B)/$K/kernelmemfs
	dd if=/dev/zero of=$@ count=10000
	dd if=$(B)/boot/bootblock of=$@ conv=notrunc
	dd if=$(B)/$K/kernelmemfs of=$@ seek=1 conv=notrunc

$(B)/boot/bootblock: boot/bootasm.S boot/bootmain.c | $(B)/boot
	$(CC) $(CFLAGS) -fno-pic -O -nostdinc -c boot/bootmain.c -o $(B)/boot/bootmain.o
	$(CC) $(CFLAGS) -fno-pic -nostdinc -c boot/bootasm.S -o $(B)/boot/bootasm.o
	$(LD) $(LDFLAGS) -N -e start -Ttext 0x7C00 -o $(B)/boot/bootblock.o $(B)/boot/bootasm.o $(B)/boot/bootmain.o
	$(OBJDUMP) -S $(B)/boot/bootblock.o > $(B)/boot/bootblock.asm
	$(OBJCOPY) -S -O binary -j .text $(B)/boot/bootblock.o $@
	perl boot/sign.pl $@

$(B)/$K/entryother: $K/entryother.S | $(B)/$K
	$(CC) $(CFLAGS) -fno-pic -nostdinc -c $< -o $(B)/$K/entryother.o
	$(LD) $(LDFLAGS) -N -e start -Ttext 0x7000 -o $(B)/$K/bootblockother.o $(B)/$K/entryother.o
	$(OBJCOPY) -S -O binary -j .text $(B)/$K/bootblockother.o $@
	$(OBJDUMP) -S $(B)/$K/bootblockother.o > $(B)/$K/entryother.asm

$(B)/$U/initcode: $U/initcode.S | $(B)/$U
	$(CC) $(CFLAGS) -nostdinc -c $< -o $(B)/$U/initcode.o
	$(LD) $(LDFLAGS) -N -e start -Ttext 0 -o $(B)/$U/initcode.out $(B)/$U/initcode.o
	$(OBJCOPY) -S -O binary $(B)/$U/initcode.out $@
	$(OBJDUMP) -S $(B)/$U/initcode.o > $(B)/$U/initcode.asm

# Binaries embedded in the kernel. `ld -b binary` names the symbols after the
# path it is given (_binary_initcode_start, ...) and the kernel refers to those
# names, so each blob is wrapped into an object from inside its own directory,
# where its bare file name yields the expected symbols.
%.blob.o: %
	cd $(<D) && $(LD) $(LDFLAGS) -r -b binary -o $(abspath $@) $(<F)

KBLOBS = $(B)/$U/initcode.blob.o $(B)/$K/entryother.blob.o

$(B)/$K/kernel: $(OBJS) $(B)/$K/entry.o $(KBLOBS) $K/kernel.ld
	$(LD) $(LDFLAGS) -T $K/kernel.ld -o $@ $(B)/$K/entry.o $(OBJS) $(KBLOBS)
	$(OBJDUMP) -S $@ > $(B)/$K/kernel.asm
	$(OBJDUMP) -t $@ | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > $(B)/$K/kernel.sym

# kernelmemfs is a copy of kernel that maintains the
# disk image in memory instead of writing to a disk.
# This is not so useful for testing persistent storage or
# exploring disk buffering implementations, but it is
# great for testing the kernel on real hardware without
# needing a scratch disk.
MEMFSOBJS = $(filter-out $(B)/$K/ide.o,$(OBJS)) $(B)/$K/memide.o
$(B)/$K/kernelmemfs: $(MEMFSOBJS) $(B)/$K/entry.o $(KBLOBS) $(B)/fs.img.blob.o $K/kernel.ld
	$(LD) $(LDFLAGS) -T $K/kernel.ld -o $@ $(B)/$K/entry.o $(MEMFSOBJS) $(KBLOBS) $(B)/fs.img.blob.o
	$(OBJDUMP) -S $@ > $(B)/$K/kernelmemfs.asm
	$(OBJDUMP) -t $@ | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > $(B)/$K/kernelmemfs.sym

tags: $(OBJS) $K/entryother.S $(B)/$U/_init
	etags boot/*.S boot/*.c $K/*.S $K/*.c $U/*.S $U/*.c mkfs/*.c $(B)/$K/vectors.S

$(B)/$K/vectors.S: $K/vectors.pl | $(B)/$K
	perl -w $< > $@

$(B)/$K/vectors.o: $(B)/$K/vectors.S
	$(CC) $(ASFLAGS) $(CPPFLAGS) -c -o $@ $<

$(B)/$K/%.o: $K/%.c | $(B)/$K
	$(CC) $(CFLAGS) $(CPPFLAGS) -c -o $@ $<

$(B)/$K/%.o: $K/%.S | $(B)/$K
	$(CC) $(ASFLAGS) $(CPPFLAGS) -c -o $@ $<

$(B)/$U/%.o: $U/%.c | $(B)/$U
	$(CC) $(CFLAGS) $(CPPFLAGS) -c -o $@ $<

$(B)/$U/%.o: $U/%.S | $(B)/$U
	$(CC) $(ASFLAGS) $(CPPFLAGS) -c -o $@ $<

ULIB = $(addprefix $(B)/$U/,ulib.o usys.o printf.o umalloc.o)

$(B)/$U/_%: $(B)/$U/%.o $(ULIB)
	$(LD) $(LDFLAGS) -N -e main -Ttext 0 -o $@ $^
	$(OBJDUMP) -S $@ > $(B)/$U/$*.asm
	$(OBJDUMP) -t $@ | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > $(B)/$U/$*.sym

$(B)/$U/_forktest: $(B)/$U/forktest.o $(ULIB)
	# forktest has less library code linked in - needs to be small
	# in order to be able to max out the proc table.
	$(LD) $(LDFLAGS) -N -e main -Ttext 0 -o $@ $(B)/$U/forktest.o $(B)/$U/ulib.o $(B)/$U/usys.o
	$(OBJDUMP) -S $@ > $(B)/$U/forktest.asm

$(B)/mkfs/mkfs: mkfs/mkfs.c $(addprefix common/,types.h fs.h stat.h param.h) | $(B)/mkfs
	gcc -Werror -Wall -I. -o $@ mkfs/mkfs.c

# Prevent deletion of intermediate files, e.g. cat.o, after first build, so
# that disk image changes after first build are persistent until clean.  More
# details:
# http://www.gnu.org/software/make/manual/html_node/Chained-Rules.html
.PRECIOUS: $(B)/$K/%.o $(B)/$U/%.o

UPROGNAMES = \
	_cat\
	_echo\
	_forktest\
	_grep\
	_init\
	_kill\
	_ln\
	_ls\
	_mkdir\
	_rm\
	_sh\
	_stressfs\
	_usertests\
	_wc\
	_zombie\

UPROGS = $(addprefix $(B)/$U/,$(UPROGNAMES))

$(B)/fs.img: $(B)/mkfs/mkfs README $(UPROGS)
	$(B)/mkfs/mkfs $@ README $(UPROGS)

-include $(B)/*/*.d

clean: 
	rm -rf $(B)
	rm -f *.tex *.dvi *.idx *.aux *.log *.ind *.ilg .gdbinit

# make a printout
FILES = $(shell grep -v '^#' doc/runoff.list)
PRINT = doc/runoff.list doc/runoff.spec README doc/toc.hdr doc/toc.ftr $(FILES)

xv6.pdf: $(PRINT)
	doc/runoff
	ls -l xv6.pdf

print: xv6.pdf

# run in emulators

# dot-bochsrc expects the images in build/.
bochs : $(B)/fs.img $(B)/xv6.img
	if [ ! -e .bochsrc ]; then ln -s dot-bochsrc .bochsrc; fi
	bochs -q

# try to generate a unique GDB port
GDBPORT = $(shell expr `id -u` % 5000 + 25000)
# QEMU's gdb stub command line changed in 0.11
QEMUGDB = $(shell if $(QEMU) -help | grep -q '^-gdb'; \
	then echo "-gdb tcp::$(GDBPORT)"; \
	else echo "-s -p $(GDBPORT)"; fi)
ifndef CPUS
CPUS := 2
endif
# One socket per CPU: QEMU >= 6.2 otherwise packs the CPUs into one socket as
# cores, and SeaBIOS then lists only one processor per package in the legacy
# MP table, so xv6 would boot with a single CPU.
SMP = -smp $(CPUS),sockets=$(CPUS)
QEMUOPTS = -drive file=$(B)/fs.img,index=1,media=disk,format=raw -drive file=$(B)/xv6.img,index=0,media=disk,format=raw $(SMP) -m 512 $(QEMUEXTRA)

qemu: $(B)/fs.img $(B)/xv6.img
	$(QEMU) -serial mon:stdio $(QEMUOPTS)

qemu-memfs: $(B)/xv6memfs.img
	$(QEMU) -drive file=$(B)/xv6memfs.img,index=0,media=disk,format=raw $(SMP) -m 256

qemu-nox: $(B)/fs.img $(B)/xv6.img
	$(QEMU) -nographic $(QEMUOPTS)

.gdbinit: .gdbinit.tmpl
	sed "s/localhost:1234/localhost:$(GDBPORT)/; s|symbol-file kernel|symbol-file $(B)/$K/kernel|" < $^ > $@

qemu-gdb: $(B)/fs.img $(B)/xv6.img .gdbinit
	@echo "*** Now run 'gdb'." 1>&2
	$(QEMU) -serial mon:stdio $(QEMUOPTS) -S $(QEMUGDB)

qemu-nox-gdb: $(B)/fs.img $(B)/xv6.img .gdbinit
	@echo "*** Now run 'gdb'." 1>&2
	$(QEMU) -nographic $(QEMUOPTS) -S $(QEMUGDB)

.PHONY: clean print bochs qemu qemu-memfs qemu-nox qemu-gdb qemu-nox-gdb

# CUT HERE
# prepare dist for students
# after running make dist, probably want to
# rename it to rev0 or rev1 or so on and then
# check in that version.

EXTRA=\
	$K/picirq.c $K/memide.c mkfs/mkfs.c $U/ulib.c $U/user.h $U/cat.c $U/echo.c $U/forktest.c $U/grep.c $U/kill.c\
	$U/ln.c $U/ls.c $U/mkdir.c $U/rm.c $U/stressfs.c $U/usertests.c $U/wc.c $U/zombie.c\
	$U/printf.c $U/umalloc.c\
	README dot-bochsrc boot/sign.pl doc/pr.pl doc/toc.hdr doc/toc.ftr\
	doc/runoff doc/runoff1 doc/runoff.list\
	.gdbinit.tmpl tools/gdbutil\

dist:
	rm -rf dist
	mkdir dist
	for i in $(FILES); \
	do \
		mkdir -p dist/$$(dirname $$i); \
		grep -v PAGEBREAK $$i >dist/$$i; \
	done
	for i in $(EXTRA); \
	do \
		mkdir -p dist/$$(dirname $$i); \
		cp $$i dist/$$i; \
	done
	sed '/CUT HERE/,$$d' Makefile >dist/Makefile
	echo >dist/doc/runoff.spec

dist-test:
	rm -rf dist
	make dist
	rm -rf dist-test
	mkdir dist-test
	cp -R dist/. dist-test
	cd dist-test; $(MAKE) print
	cd dist-test; $(MAKE) bochs || true
	cd dist-test; $(MAKE) qemu

# update this rule (change rev#) when it is time to
# make a new revision.
tar:
	rm -rf /tmp/xv6
	mkdir -p /tmp/xv6
	cp -R dist/. /tmp/xv6
	(cd /tmp; tar cf - xv6) | gzip >xv6-rev10.tar.gz  # the next one will be 10 (9/17)

.PHONY: dist-test dist
