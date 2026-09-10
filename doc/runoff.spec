# Is sheet 01 (after the TOC) a left sheet or a right sheet?
sheet1: left

# "left" and "right" specify which page of a two-page spread a file
# must start on.  "left" means that a file must start on the first of
# the two pages.  "right" means it must start on the second of the two
# pages.  The file may start in either column.
#
# "even" and "odd" specify which column a file must start on.  "even"
# means it must start in the left of the two columns (00).  "odd" means it
# must start in the right of the two columns (50).
#
# You'd think these would be the other way around.

# types.h either
# param.h either
# defs.h either
# x86.h either
# asm.h either
# mmu.h either
# elf.h either
# mp.h either

even: kernel/entry.S  # mild preference
even: kernel/entryother.S  # mild preference
even: kernel/main.c
# mp.c don't care at all
# even: initcode.S
# odd: init.c

left: kernel/spinlock.h
even: kernel/spinlock.h

# This gets struct proc and allocproc on the same spread
left: kernel/proc.h
even: kernel/proc.h

# goal is to have two action-packed 2-page spreads,
# one with
#     userinit growproc fork exit wait
# and another with
#     scheduler sched yield forkret sleep wakeup1 wakeup
right: kernel/proc.c   # VERY important
even: kernel/proc.c   # VERY important

# A few more action packed spreads
# page table creation and process loading
#     walkpgdir mappages setupkvm switch[ku]vm inituvm (loaduvm)
# process memory management
#     allocuvm deallocuvm freevm
left: kernel/vm.c

even: kernel/kalloc.c  # mild preference

# syscall.h either
# trapasm.S either
# traps.h either
# even: trap.c
# vectors.pl either
# syscall.c either
# sysproc.c either

# buf.h either
# dev.h either
# fcntl.h either
# stat.h either
# file.h either
# fs.h either
# fsvar.h either
# left: ide.c # mild preference
even: kernel/ide.c
# odd: bio.c

# log.c fits nicely in a spread
even: kernel/log.c
left: kernel/log.c

# with fs.c starting on 2nd column of a left page, we get these 2-page spreads:
#	ialloc iupdate iget idup ilock iunlock iput iunlockput
#	bmap itrunc stati readi writei
#	namecmp dirlookup dirlink skipelem namex namei
#	fileinit filealloc filedup fileclose filestat fileread filewrite
# starting on 2nd column of a right page is not terrible either
odd: kernel/fs.c   # VERY important
left: kernel/fs.c  # mild preference
# file.c either
# exec.c either
# sysfile.c either

# Mild preference, but makes spreads of mp.c, lapic.c, and ioapic.c+picirq.c
even: kernel/mp.c
left: kernel/mp.c

# even: pipe.c  # mild preference
# string.c either
# left: kbd.h  # mild preference
even: kernel/kbd.h
even: kernel/console.c
odd: user/sh.c

even: boot/bootasm.S   # mild preference
even: boot/bootmain.c  # mild preference
