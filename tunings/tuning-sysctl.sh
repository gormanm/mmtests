#!/bin/bash
# This script allows arbitrary tuning of sysctl

. $SHELLPACK_INCLUDE/common.sh

sysctl $TUNING_SYSCTL || die "sysctl failed"
