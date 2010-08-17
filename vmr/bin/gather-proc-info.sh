
#[ -e /proc/sched_debug ]    || echo "not a CFS kernel? continuing anyway."
#[ "`id | grep root`" = "" ] && { echo "please run this as root!"; exit -1; }

if [ "$1" = "" ]; then
	FILE=debug-info-`date +%Y.%m.%d-%H.%M.%S`
else
	FILE="$1"
fi

echo "-- pagetables: --"             >> $FILE
mount -t debugfs nodev /sys/kernel/debug 2>/dev/null >/dev/null
cat /sys/kernel/debug/kernel_page_tables >> $FILE 2>/dev/null
echo "-- interrupts: --"             >> $FILE
cat /proc/interrupts                 >> $FILE 2>/dev/null
echo "-- cpuinfo: --"                >> $FILE
cat /proc/cpuinfo                    >> $FILE 2>/dev/null
echo "-- cpufreq: --"                >> $FILE
cat /sys/devices/system/cpu/cpu*/cpufreq/* \
                                     >> $FILE 2>/dev/null
echo "-- meminfo: --"                >> $FILE
cat /proc/meminfo                    >> $FILE 2>/dev/null
echo "-- buddyinfo: --"              >> $FILE
cat /proc/buddyinfo                  >> $FILE 2>/dev/null
echo "-- vmstat: --"                 >> $FILE
cat /proc/vmstat                     >> $FILE 2>/dev/null
echo "-- zoneinfo: --"               >> $FILE
cat /proc/zoneinfo                   >> $FILE 2>/dev/null
echo "-- pagetypeinfo: --"           >> $FILE
cat /proc/pagetypeinfo               >> $FILE 2>/dev/null
echo "-- slabinfo proc: --"          >> $FILE
cat /proc/slabinfo                   >> $FILE 2>/dev/null
echo "-- slabinfo util: --"          >> $FILE
slabinfo -AD                         >> $FILE 2>/dev/null
echo "-- slqbinfo: --"               >> $FILE
slqbinfo -AD                         >> $FILE 2>/dev/null
echo "-- dmesg: --"                  >> $FILE
dmesg -s 10000000                    >> $FILE 2>/dev/null
echo "-- uptime: --"                 >> $FILE
uptime                               >> $FILE 2>/dev/null
echo "-- uname: --"                  >> $FILE
uname -a                             >> $FILE 2>/dev/null
