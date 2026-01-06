#!/usr/bin/awk -f

/core_i:/ {
	sub("core_i: ", "", $0)
	len=split($0, arr)
	for (i = 0; i < len; i++) {
		cpumap[i] = arr[i+1]
	}
}

/^int_.*:/ {
	# sub($1" ", "", $0)
	metric=$1
	sub("\\):", "",  metric)
	sub(":",   "",  metric)
	sub("\\(", "_", metric)
	sub("%", "%age", metric)
	sub(/int_.*: /, "", $0)

	ratio="_"
	if (metric == "int_n_per_sec") {
		ratio="R"
	}
	len=split($0, vals)
	for (i = 1; i <= len; i++) {
		print metric"\tcpu"cpumap[i-1]"\t_\t1\t"vals[i]"\t"ratio
	}
}
