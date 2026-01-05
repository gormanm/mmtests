#!/usr/bin/awk -f

$0 ~ /Copy:/ { print "Copy\t"threads"\t_\t"iteration"\t"$2"\t_" }
