#!/usr/bin/awk -f

/^jbb2015.result.metric.critical-jOPS/ {
	jopsCrit=$NF
}

/^jbb2015.result.metric.max-jOPS/ {
	jopsMax=$NF
}

/^jbb2015.result.SLA-10000-jOPS/  { jops10000=$NF }
/^jbb2015.result.SLA-25000-jOPS/  { jops25000=$NF }
/^jbb2015.result.SLA-50000-jOPS/  { jops50000=$NF }
/^jbb2015.result.SLA-75000-jOPS/  { jops75000=$NF }
/^jbb2015.result.SLA-100000-jOPS/ { jops100000=$NF }

END {
	MaxPct10k=jops10000/jopsMax*100
	MaxPct25k=jops25000/jopsMax*100
	MaxPct50k=jops50000/jopsMax*100
	MaxPct75k=jops75000/jopsMax*100
	MaxPct100k=jops100000/jopsMax*100
	print "JOPS-Max\t_\t_\t1\t"jopsMax"\t_"
	print "JOPS-Critical\t_\t_\t1\t"jopsCrit"\tR"
	print "JOPS-10000us\t_\t_\t1\t"jops10000"\t_"
	print "JOPS-25000us\t_\t_\t1\t"jops25000"\t_"
	print "JOPS-50000us\t_\t_\t1\t"jops50000"\t_"
	print "JOPS-75000us\t_\t_\t1\t"jops75000"\t_"
	print "JOPS-100000us\t_\t_\t1\t"jops100000"\t_"

	print "pctMax-10000us\t_\t_\t1\t"MaxPct10k"\t_"
	print "pctMax-25000us\t_\t_\t1\t"MaxPct25k"\t_"
	print "pctMax-50000us\t_\t_\t1\t"MaxPct50k"\t_"
	print "pctMax-75000us\t_\t_\t1\t"MaxPct75k"\t_"
	print "pctMax-100000us\t_\t_\t1\t"MaxPct100k"\t_"
}
