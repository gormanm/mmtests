#!/bin/bash

# Copyright (C) 2017 SUSE
# Author: Libor Pechacek (derived from klp_tc_3 with minor modification)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, see <http://www.gnu.org/licenses/>.

# Test Case 1: Basic patch/unpatch

set -e
. $(dirname $0)/klp_tc_functions.sh
klp_tc_init "Test Case 1: Basic patch/unpatch"

klp_tc_milestone "Compiling kernel live patch"
PATCH_KO="$(klp_create_patch_module tc_1 ${KLP_TEST_SYSCALL_FN_PREFIX}sys_getpid)"
PATCH_MOD_NAME="$(basename "$PATCH_KO" .ko)"

klp_tc_milestone "Compiling call_getpid"
PATCH_DIR="/tmp/live-patch/tc_1"
gcc -o "$PATCH_DIR"/call_getpid "$SOURCE_DIR"/klp_tc_3-call_getpid.c

klp_tc_milestone "Inserting getpid patch"
insmod "$PATCH_KO"
if [ ! -e /sys/kernel/livepatch/"$PATCH_MOD_NAME" ]; then
   klp_tc_abort "don't see $PATCH_MOD_NAME in live patch sys directory"
fi
register_mod_for_unload "$PATCH_MOD_NAME"

klp_tc_milestone "Wait for completion"
if ! klp_wait_complete "$PATCH_MOD_NAME" 61; then
    klp_dump_blocking_processes
    klp_tc_abort "patching didn't finish in time"
fi

# test passed if execution reached this line
# failures beyond this point are not test case failures
klp_tc_milestone "Terminating call_getpid"

klp_tc_exit
