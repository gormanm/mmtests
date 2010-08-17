#!/bin/bash

insmod ./src/core/vmregress_core.o
insmod ./src/core/pagetable.o
insmod ./src/sense/kvirtual.o
insmod ./src/sense/pagemap.o
insmod ./src/sense/sizes.o
insmod ./src/sense/zone.o
insmod ./src/test/alloc.o
insmod ./src/test/fault.o
insmod ./src/test/testproc.o
insmod ./src/bench/mmap.o
