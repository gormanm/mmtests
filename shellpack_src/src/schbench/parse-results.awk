#!/usr/bin/awk -f

BEGIN {
	iteration=1
	sample=""
}

$0 ~ /percentile/ {
	metric=$1
}

$0 ~ /current rps/ {
	printf "%s",sample
	sample=""
	iteration++
}

$0 ~ /  20.0th:/ {gsub(/th:/, "th");sample=(sample)(metric"\t"$1"\t"workers"\t"iteration"\t"$2"\t_\n") }
$0 ~ /  50.0th:/ {gsub(/th:/, "th");sample=(sample)(metric"\t"$1"\t"workers"\t"iteration"\t"$2"\t_\n") }
$0 ~ /  90.0th:/ {gsub(/th:/, "th");sample=(sample)(metric"\t"$1"\t"workers"\t"iteration"\t"$2"\t_\n") }
$0 ~ /  99.0th:/ {gsub(/th:/, "th");sample=(sample)(metric"\t"$1"\t"workers"\t"iteration"\t"$2"\t_\n") }
$0 ~ /  99.9th:/ {gsub(/th:/, "th");sample=(sample)(metric"\t"$1"\t"workers"\t"iteration"\t"$2"\t_\n") }

$0 ~ /* 20.0th:/ {gsub(/th:/, "th");sample=(sample)(metric"\t"$2"\t"workers"\t"iteration"\t"$3"\t_\n") }
$0 ~ /* 50.0th:/ {gsub(/th:/, "th");sample=(sample)(metric"\t"$2"\t"workers"\t"iteration"\t"$3"\t_\n") }
$0 ~ /* 90.0th:/ {gsub(/th:/, "th");sample=(sample)(metric"\t"$2"\t"workers"\t"iteration"\t"$3"\t_\n") }
$0 ~ /* 99.0th:/ {gsub(/th:/, "th");sample=(sample)(metric"\t"$2"\t"workers"\t"iteration"\t"$3"\t_\n") }
$0 ~ /* 99.9th:/ {gsub(/th:/, "th");sample=(sample)(metric"\t"$2"\t"workers"\t"iteration"\t"$3"\t_\n") }
