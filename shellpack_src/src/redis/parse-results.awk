#!/usr/bin/awk -f

/test/ { next }

{
	gsub("\"", "", $0)
	split($0, arr, ",")
	sub(/ \(.*\)/, "", arr[1])

	op=arr[1]
	rps=arr[2]/1000
	latMin=arr[4]*1000
	latAvg=arr[3]*1000
	lat95=arr[6]*1000
	lat99=arr[7]*1000
	latMax=arr[8]*1000

	print op"-RPS""\t"nr_client"\t_\t"iteration"\t"rps"\tR"
	print op"-latMin\t"nr_client"\t_\t"iteration"\t"latMin"\t_"
	print op"-latAvg\t"nr_client"\t_\t"iteration"\t"latAvg"\t_"
	print op"-lat95\t"nr_client"\t_\t"iteration"\t"lat95"\t_"
	print op"-lat99\t"nr_client"\t_\t"iteration"\t"lat99"\t_"
	print op"-latMax\t"nr_client"\t_\t"iteration"\t"latMax"\t_"
}
