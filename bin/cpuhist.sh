#!/bin/bash
# Script to parse a file containing the output of 'perf script' and determine
# how many times each CPU was chosen for a newly created task.
# The results are plotted as a histogram, using gnuplot.
#
# Dependencies: perf, gnuplot
#
# Kostas Peletidis, 2024-09-05
#
TRACESTR="sched_wakeup_new"

function show_usage() {
    echo "Usage: $0 perf_script_output_file [data_set_name]"
}

## Function to generate a gnuplot script for a histogram
## Parameters:
## $1: Name of input data file to plot
## $2: Name of output image file
## $3: Title of the plotted data e.g. "Baseline" or "XYZ Beta1"
function generate_histogram_script() {
    echo "reset
	  set boxwidth 0.5
	  set xrange [-0.5:]
	  set grid ytics linestyle 0
	  set style fill solid 0.20 border

	  set style data histogram
	  set style histogram rowstacked

	  set terminal png nocrop enhanced size 1280,960 font \"arial,12.0\"
	  set output '"$2"'
	  set title 'CPU selections'
	  set xlabel 'CPU #'
	  set ylabel 'No. of Selections'
	  plot '"$1"' u 1:2 title '"$3"' with boxes, \\
	  '"$1"' u 1:(\$2+50):2 with labels font \"arial,8.0\" title \"\"" \
    | sed -e 's/^[ \t]*//'
}

if [ $# -eq 0 -o $# -gt 2 ]; then
    show_usage
    exit 1
elif [ ! -f "$1" ]; then
    echo "File $1 does not exist"
    exit 2
fi

UP_TO_THE_DOT=`echo $1 | awk -F '.' '{print $1}'`
DATAFILE="${UP_TO_THE_DOT}_cpu_data"
OUTFILE="${UP_TO_THE_DOT}_cpu_histogram.png"
GNUPLOTFILE="${UP_TO_THE_DOT}_cpu_histogram.gnuplot"
DATANAME="$2"

grep "$TRACESTR" $1 | awk '{print $8}' | sort | uniq -c | awk '{print $2" "$1}' | tr -d 'A-Z:' > "$DATAFILE"

generate_histogram_script "$DATAFILE" "$OUTFILE" "$DATANAME" > "$GNUPLOTFILE"
gnuplot "$GNUPLOTFILE"

exit 0

