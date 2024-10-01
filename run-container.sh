#!/bin/bash

# Author: Andreas Herrmann <aherrmann@suse.com>
# script to run mmtests test in container

set ${MMTESTS_SH_DEBUG:-+x}
shopt -s extglob

function parse_args() {
	declare -ga CONFIGS
	local scriptname=$(basename $0)
	local dirname=$(dirname $0)
	local opts=$(getopt -o c:hi:Imno:p --long config:,help,run-monitor \
			    --long no-monitor,image:,interactive,os-release: \
			    --long privileged \
			    -n \'${scriptname}\' -- "$@")
	eval set -- "${opts}"

	while true; do
		case "${1}" in
		-c|--config)
			CONFIGS+=(${2})
			shift 2;;
		-m|--run-monitor)
			monitor=-m
			shift;;
		-n|--no-monitor)
			monitor=-n
			shift;;
		-i|--image)
			image=$2
			shift 2;;
		-I|--interactive)
			interactive=true
			shift;;
		-o|--os-release)
			cpe_name=$2
			shift 2;;
		-p|--privileged)
			privileged=true
			shift;;
		-h|--help) cat <<EOF
${scriptname} [OPTIONS] <runname>

Mmtests containerization script.

Options:

  -c, --config        mmtests config file (default: config)
  -h, --help          print this help text and exit
  -i, --image         container image (default: automatic selection)
  -I, --interactive   setup container and start bash for interaction
  -m, --run-monitor   enable monitoring
  -n, --no-monitor    disable monitoring
  -o, --os-release    specify cpe_name for desired image
  -p, --privileged    run container in privileged mode

Runtime variables:

  MMTESTS_CONTAINER_CLI   command line interface: 'podman' (default) or 'docker'

  Set the following to 'yes' to change container environment.

  CONTAINER_CAP_SYS_NICE  grant CAP_SYS_NICE (see capabilities(7))
  CONTAINER_CAP_IPC_LOCK  grant CAP_IPC_LOCK (see capabilities(7))
  CONTAINER_NO_APPARMOR   turn off apparmor confinement
  CONTAINER_NO_FIPS       remove FIPS specific packages
  CONTAINER_NO_PIDS_LIMIT increase pids.max value (unlimited or very large)
  CONTAINER_NO_SECCOMP    turn off seccomp confinement
  CONTAINER_PRIVILEGED    run container in privileged mode

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
	# import variables
	source ${SCRIPTDIR}/shellpacks/common-config.sh
	# import helpers, e.g. import_configs
	source ${SCRIPTDIR}/shellpacks/common.sh
	runname=${runname:-default}
	image=${image:-autoselect}
	cli=${MMTESTS_CONTAINER_CLI:-podman}
	if [ "${cli}" != "docker" -a "${cli}" != "podman" ]; then
		echo "ERROR: Container runtime not supported"
		exit 22
	fi
	install-depends gawk
}

function import_config() {
	import_configs
}

# https://www.freedesktop.org/software/systemd/man/os-release.html
function check_os_version() {
	local cpe=$(grep CPE_NAME /etc/os-release | awk -F "=" '{print $2}' | sed -e 's/"//g')

	if [ -n "${cpe_name}" ]; then
		cpe=${cpe_name}
	fi

	# e.g.:
	# CPE_NAME="cpe:/o:suse:sles:15:sp4"
	# CPE_NAME="cpe:/o:opensuse:tumbleweed:20220729"
	# CPE_NAME="cpe:/o:opensuse:leap:15.4"

	distro=$(echo ${cpe} | awk -F ":" '{print $3}')
	version=$(echo ${cpe} | awk -F ":" '{print $4}')
	release=$(echo ${cpe} | awk -F ":" '{print $5}')
	sp=$(echo ${cpe} | awk -F ":" '{print $6}')

	echo "Host OS. distro: \"${distro}\", version: \"${version}\","\
	     "release: \"${release}\", sp: \"${sp}\""
}

function prepare_container_cli() {
	echo "Installing ${cli}"
	install-depends ${cli}
	if [ "${cli}" = "docker" ]; then
		echo "Starting dockerd"
		dockerd&
		sleep 2
	fi
}

function autoselect_image() {
	if [ "${distro}" = "opensuse" ]; then
		# images from https://registry.opensuse.org/
		if [ "${version}" = "tumbleweed" ]; then
			image=registry.opensuse.org/opensuse/tumbleweed:latest
		elif [ "${version}" = "leap" ]; then
			case "${release}" in
			15.3)
				image=registry.opensuse.org/opensuse/leap:15.3
				;;
			15.4)
				image=registry.opensuse.org/opensuse/leap:15.4
				;;
			15.5)
				image=registry.opensuse.org/opensuse/leap:15.5
				;;
			*)
				echo "ERROR: Distribution release not supported"
				cleanup_container_cli
				exit 22
			esac
		else
			echo "ERROR: Distribution version not supported"
			cleanup_container_cli
			exit 22
		fi
	elif [ "${distro}" = "suse" ]; then
		# images from https://registry.suse.com/#sle
		if [ "${version}" = "sles" -a "${release}" = "15" ]; then
			case "${sp}" in
			sp2)
				image=registry.suse.com/suse/sle15:15.2
				;;
			sp3)
				image=registry.suse.com/suse/sle15:15.3
				;;
			sp4)
				image=registry.suse.com/suse/sle15:15.4
				;;
			sp5)
				image=registry.suse.com/suse/sle15:15.5
				;;
			sp6)
				image=registry.suse.com/suse/sle15:15.6
				;;
			*)
				echo "ERROR: Distribution SP not supported"
				cleanup_container_cli
				exit 22
			esac
		else
			echo "ERROR: Distribution version/release not supported"
			cleanup_container_cli
			exit 22
		fi
	else
		echo "ERROR: Distribution not supported"
		cleanup_container_cli
		exit 22
	fi
}

function pull_image() {

	if [ "${image}" = "autoselect" ]; then
		autoselect_image
	fi

	echo "Pulling ${image}"
	${cli} pull ${image}
}

function set_runargs() {
	runargs=""
	local dtm=$(systemctl show --property DefaultTasksMax)

	# unlimited pids.max might not be possible due to systemd default config
	if [ "${CONTAINER_NO_PIDS_LIMIT}" = "yes" ]; then
		if $(echo ${dtm} | grep -qi "infinity"); then
			runargs="--pids-limit=-1"
		else
			# set arbitrarily large pid limit
			runargs="--pids-limit=15000"
		fi
	fi

	# allow to increase scheduling priority or to change scheduling policy
	if [ "${CONTAINER_CAP_SYS_NICE}" = "yes" ]; then
		runargs="${runargs} --cap-add=sys_nice"
	fi

	# allow use of mlockall
	if [ "${CONTAINER_CAP_IPC_LOCK}" = "yes" ]; then
		runargs="${runargs} --cap-add=ipc_lock"
	fi

	# turn off apparmor confinement
	if [ "${CONTAINER_NO_APPARMOR}" = "yes" ]; then
		runargs="${runargs} --security-opt apparmor=unconfined"
	fi

	# turn off seccomp confinement
	if [ "${CONTAINER_NO_SECCOMP}" = "yes" ]; then
		runargs="${runargs} --security-opt seccomp=unconfined"
	fi

	if [[ "${CONTAINER_PRIVILEGED}" = "yes" || "${privileged}" = "true" ]]; then
		runargs="${runargs} --privileged"
	fi

	if [ -n "${runargs}" ]; then
		echo "Additional args: \"${runargs}\""
	fi
}

function start_container() {
	c_mmtests_dir=/$(basename ${SCRIPTDIR})

	echo "Mounting testdisk"
	./run-mmtests.sh ${monitor} --mount-only -c ${CONFIGS[0]} ${runname}-tmp
	rm -rf ${SHELLPACK_LOG_BASE}/${runname}-tmp

	set_runargs

	echo "Starting container"
	# bind mount testdisk in container
	container_id=$(${cli} run -t -d ${runargs} \
			      --mount type=bind,source=${SHELLPACK_TEST_MOUNT},target=${c_mmtests_dir}/work/testdisk \
			      ${image})
	echo "container_id: ${container_id}"
}

# some distro specific preparations
function update_container() {
	if $(echo ${image} | grep -q ubuntu); then
		${cli} exec ${container_id} apt-get update
	elif $(echo ${image} | grep -q fedora); then
		${cli} exec ${container_id} yum -y install perl
	elif $(echo ${image} | grep -q tumbleweed); then
		${cli} exec ${container_id} zypper install -y perl
	elif $(echo ${image} | grep -q "leap\|sle15"); then
		if [ "${CONTAINER_NO_FIPS}" = "yes" ]; then
			${cli} exec ${container_id} zypper remove -y \
			       --clean-deps patterns-base-fips
		fi
	fi
}

function prepare_mmtests() {
	local i
	echo "Copying and preparing mmtests"

	for i in $(ls -d ${SCRIPTDIR}/!(work)); do
		${cli} cp $i ${container_id}:${c_mmtests_dir}/
	done
	${cli} exec ${container_id} touch ~/.mmtests-auto-package-install
	${cli} exec ${container_id} touch ~/.mmtests-auto-package-downgrade
	${cli} exec -w /root ${container_id} \
	       bash -c "echo -e \"[http]\n\tsslVerify = false\" > .gitconfig"
}

function start_bash() {
	echo "Starting bash"
	${cli} exec -it -w ${c_mmtests_dir} ${container_id} bash
}

function run_mmtests() {
	echo "Running mmtests"
	# don't mount testdisk, use bind mounted test disk instead
	${cli} exec -w ${c_mmtests_dir} ${container_id} \
	       ./run-mmtests.sh ${monitor} --no-mount -c ${CONFIGS[0]} ${runname}
}

function copy_results() {
	echo "Copying result directory"
	mkdir -p ${SHELLPACK_LOG_BASE}
	${cli} cp ${container_id}:${c_mmtests_dir}/work/log/${runname} ${SHELLPACK_LOG_BASE}
}

function log_host_info() {
	local host_log=${SHELLPACK_LOG_BASE}/${runname}/host

	mkdir -p ${host_log}
	dmesg > ${host_log}/dmesg
	gzip -f ${host_log}/dmesg
	journalctl -k 2>/dev/null > ${host_log}/journalctl-kernel
	gzip -f ${host_log}/journalctl-kernel
	cp /etc/os-release ${host_log}/

	${cli} info > ${host_log}/container_cli
	env | grep "^CONTAINER" > ${host_log}/container
	${cli} inspect ${container_id} >> ${host_log}/container
}

function stop_container() {
	if [ -n "${container_id}" ]; then
		echo "Stopping container ${container_id}"
		${cli} container stop ${container_id}
		echo "Removing container ${container_id}"
		${cli} container rm ${container_id}
	fi
	# unconditionally umount testdisk
	umount work/testdisk 2>/dev/null
}

function cleanup_container_cli() {
	echo "Removing image ${image}"
	${cli} image rm ${image}

	if [ "${cli}" = "docker" ]; then
		echo "Stopping dockerd"
		pkill -SIGTERM dockerd
	fi
}

function main() {
	parse_args "$@"
	prolog
	import_config
	check_os_version
	prepare_container_cli
	pull_image
	start_container
	update_container
	prepare_mmtests
	if [ "${interactive}" = "true" ]; then
		start_bash
	else
		run_mmtests
		copy_results
		log_host_info
	fi
	stop_container
	cleanup_container_cli
}

main "$@"
