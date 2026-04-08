#!/usr/bin/awk -f

BEGIN {
	runtime=1
	sample=""
}

$0 ~ /percentile/ {
	metric=$1
}

$0 ~ /Wakeup Latencies.*runtime/ {
	runtime=$6
}

$0 ~ /current rps/ {
	printf "%s",sample
	sample=""
}

$0 ~ /  20.0th:/ {gsub(/th:/, "th");sample=(sample)(metric"\t"$1"\t"workers"\t"runtime"\t"$2"\t_\n") }
$0 ~ /  50.0th:/ {gsub(/th:/, "th");sample=(sample)(metric"\t"$1"\t"workers"\t"runtime"\t"$2"\t_\n") }
$0 ~ /  90.0th:/ {gsub(/th:/, "th");sample=(sample)(metric"\t"$1"\t"workers"\t"runtime"\t"$2"\t_\n") }
$0 ~ /  99.0th:/ {gsub(/th:/, "th");sample=(sample)(metric"\t"$1"\t"workers"\t"runtime"\t"$2"\t_\n") }
$0 ~ /  99.9th:/ {gsub(/th:/, "th");sample=(sample)(metric"\t"$1"\t"workers"\t"runtime"\t"$2"\t_\n") }

$0 ~ /* 20.0th:/ {gsub(/th:/, "th");sample=(sample)(metric"\t"$2"\t"workers"\t"runtime"\t"$3"\t_\n") }
$0 ~ /* 50.0th:/ {gsub(/th:/, "th");sample=(sample)(metric"\t"$2"\t"workers"\t"runtime"\t"$3"\t_\n") }
$0 ~ /* 90.0th:/ {gsub(/th:/, "th");sample=(sample)(metric"\t"$2"\t"workers"\t"runtime"\t"$3"\t_\n") }
$0 ~ /* 99.0th:/ {gsub(/th:/, "th");sample=(sample)(metric"\t"$2"\t"workers"\t"runtime"\t"$3"\t_\n") }
$0 ~ /* 99.9th:/ {gsub(/th:/, "th");sample=(sample)(metric"\t"$2"\t"workers"\t"runtime"\t"$3"\t_\n") }
