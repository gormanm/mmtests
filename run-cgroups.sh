#!/bin/bash

# Author: Andreas Herrmann <aherrmann@suse.com>
# script to setup/run mmtests tests in cgroups

set ${MMTESTS_SH_DEBUG:-+x}

function parse_args() {
	declare -ga CONFIGS
	local scriptname=$(basename $0)
	local dirname=$(dirname $0)
	local opts=$(getopt -o hc: --long config:,help \
			    -n \'${scriptname}\' -- "$@")
	eval set -- "${opts}"

	while true; do
		case "${1}" in
		-c|--config)
			CONFIGS+=(${2})
			shift 2;;
		-h|--help) cat <<EOF
${scriptname} [OPTIONS] <runname>

Cgroup handling script.

Options:

  -c, --config <file> cgroup mmtests config file
  -h, --help          print this help text and exit

EOF
			   shift; exit 0;;
		*) break;;
		esac
	done
	export SCRIPTDIR=$(cd "${dirname}" && pwd)
	shift
	runname=$1
}

function prolog() {
	if [ ${#CONFIGS[*]} -eq 0 ]; then
		CONFIGS[0]=config
	elif [ ${#CONFIGS[*]} -gt 1 ]; then
		echo "ERROR: More than one configuration file specified"
		exit 22
	fi
	# set_environment
	export PATH="${SCRIPTDIR}/bin:${PATH}"
	cd ${SCRIPTDIR}
	# import helpers, e.g. import_configs
	source ${SCRIPTDIR}/shellpacks/common.sh
	runname=${runname:-default}
}

function import_config() {
	import_configs
}

function parse_config() {
	declare -ga CG_CONFIGS CG_TYPES CG_ATTRIBS CG_VALUES
	local -i i=1
	local c a t v

	echo "Parsing config"

	while true; do
		c=$(eval echo \${CGROUP_${i}_CONFIG})
		if [ "$c" = "" ]; then
			if [ $i -eq 1 ]; then
				echo "ERROR: no cgroup specification found in config file"
				exit 22
			fi
			break
		fi
		t=$(eval echo \${CGROUP_${i}_TYPE})
		a=$(eval echo \${CGROUP_${i}_ATTRIB})
		v=$(eval echo \${CGROUP_${i}_VALUE})
		CG_CONFIGS+=($c)
		CG_TYPES+=($t)
		CG_ATTRIBS+=($a)
		CG_VALUES+=($v)
		echo "cg ${#CG_CONFIGS[*]}: '$c', $t, $a=$v"
		i=$[$i+1]
	done
}

function mount_only() {
	echo "Mounting testdisk"
	./run-mmtests.sh --mount-only -n -c ${CONFIGS[0]} ${runname}-mo
}

function build_only() {
	local i m max=${#CG_CONFIGS[*]}
	echo "Installing benchmark(s)"
	for i in ${!CG_CONFIGS[*]}; do
		m=$[$i+1]
		${SCRIPTDIR}/run-mmtests.sh --no-mount --build-only -n \
			    -c ${CG_CONFIGS[$i]} \
			    ${runname}-cg_${m}_$max
	done
}

function write_service() {
	local n=$1 m=$[$1+1] max=$2 sfile efile

	sfile=/etc/systemd/system/$(basename ${CG_CONFIGS[$n]})-$n.service
	efile=${SCRIPTDIR}/work/tmp/$(basename ${CG_CONFIGS[$n]})-$n.sh

	echo
	echo "Creating exec file for cgroup $m: ${efile}"
	cat >${efile} <<EOF
#!/bin/bash

cd ${SCRIPTDIR}
./run-mmtests.sh --no-mount -n -c ${CG_CONFIGS[$n]} ${runname}-cg_${m}_${max}
EOF
	cat ${efile}
	chmod u+x ${efile}

	echo
	echo "Creating systemd service file for cgroup $m: ${sfile}"
	cat >${sfile} <<EOF
[Service]
Type=oneshot
Slice=MMTESTS.slice
ExecStart=${efile}
${CG_TYPES[$n]}=true
${CG_ATTRIBS[$n]}=${CG_VALUES[$n]}
EOF
	cat ${sfile}
}

function run_only() {
	local services i
	for i in ${!CG_CONFIGS[*]}; do
		write_service $i ${#CG_CONFIGS[*]}
		services="${services} $(basename ${CG_CONFIGS[$i]})-$i"
	done
	echo "Starting services ${services}"
	systemctl --wait start ${services}
	echo "Services finished"
}

function write_service_monitor() {
	local sfile efile

	sfile=/etc/systemd/system/$(basename ${CONFIGS[0]})-monitor.service
	efile=${SCRIPTDIR}/work/tmp/$(basename ${CONFIGS[0]})-monitor.sh

	echo
	echo "Creating exec file for cgroup monitor: ${efile}"
	cat >${efile} <<EOF
#!/bin/bash

cd ${SCRIPTDIR}
export MONITOR_FOREVER=yes
./gather-monitor-cgroup.sh
EOF
	cat ${efile}
	chmod u+x ${efile}

	echo
	echo "Creating systemd service file for cgroup monitor: ${sfile}"
	cat >${sfile} <<EOF
[Service]
Type=oneshot
Slice=MMTESTS.slice
ExecStart=${efile}
EOF
	cat ${sfile}
}

function start_monitor() {
	local service=$(basename ${CONFIGS[0]})-monitor
	./generate-monitor-only.sh -c $(pwd)/${CONFIGS[0]} cgroup
	write_service_monitor
	systemctl start ${service} &
	echo "Monitoring started"
}

function stop_monitor() {
	local service=$(basename ${CONFIGS[0]})-monitor
	systemctl kill --signal SIGINT ${service}
	echo "Monitoring stopped"
}

function main() {
	parse_args "$@"
	prolog
	import_config
	parse_config
	mount_only
	build_only
	start_monitor
	run_only
	stop_monitor
}

main "$@"
