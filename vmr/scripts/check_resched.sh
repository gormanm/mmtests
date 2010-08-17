#!/bin/bash
# 
# This checks if the need_resched() function is defined is the file
# passed by command line

if [ ! -e $1 ]; then
  echo check_resched: $1 does not exist
  exit
fi

TEST=`grep "static inline int need_resched(void)" "$1"`
if [ "$TEST" != "" ]; then
  echo "#define HAVE_NEED_RESCHED"
fi

