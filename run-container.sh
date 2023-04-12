#!/bin/bash

# Author: Andreas Herrmann <aherrmann@suse.com>
# script to run mmtests test in container

set ${MMTESTS_SH_DEBUG:-+x}

function parse_args() {
	declare -ga CONFIGS
	local scriptname=$(basename $0)
	local dirname=$(dirname $0)
	local opts=$(getopt -o c:hmno: --long config:,help,run-monitor \
			    --long no-monitor,os-release: \
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
		-o|--os-release)
			cpe_name=$2
			shift 2;;
		-h|--help) cat <<EOF
${scriptname} [OPTIONS] <runname>

Mmtests containerization script.

Options:

  -c, --config <file> mmtests config file
  -h, --help          print this help text and exit
  -m, --run-monitor   enable monitoring
  -n, --no-monitor    disable monitoring
  -o, --os-release    specify cpe_name for desired image

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
	runname=${runname:-default}
	cli=${MMTESTS_CONTAINER_CLI:-docker}
	if [ "${cli}" != "docker" -a "${cli}" != "podman" ]; then
		echo "ERROR: Container runtime not supported"
		exit 22
	fi
}

# https://www.freedesktop.org/software/systemd/man/os-release.html
function check_os_version() {
	local cpe=$(grep CPE_NAME /etc/os-release | awk -F "=" '{print $2}' | sed -e 's/"//g')

	if [ -n "${cpe_name}" ]; then
		cpe=${cpe_name}
	fi

	# e.g.:
	# CPE_NAME="cpe:/o:suse:sles:15:sp2"
	# CPE_NAME="cpe:/o:suse:sles:15:sp3"
	# CPE_NAME="cpe:/o:suse:sles:15:sp4"
	# CPE_NAME="cpe:/o:suse:sles:15:sp5"
	# CPE_NAME="cpe:/o:opensuse:tumbleweed:20220729"
	# CPE_NAME="cpe:/o:opensuse:leap:15.3"
	# CPE_NAME="cpe:/o:opensuse:leap:15.4"
	# CPE_NAME="cpe:/o:opensuse:leap:15.5"

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

function pull_image() {
	local image

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
			sp5) # not available yet, use SP4 BCI
				image=registry.suse.com/suse/sle15:15.4
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

	echo "Pulling ${image}"
	${cli} pull ${image}
	image_id=$(${cli} images| grep registry | awk '{print $3}')
	echo "image_id: ${image_id}"
}

function start_container() {
	echo "Starting container"

	# mount testdisk in host system
	./run-mmtests.sh ${monitor} --mount-only -c ${CONFIGS[0]} ${runname}-tmp
	rm -rf ${SHELLPACK_LOG_BASE}/${runname}-tmp
	# bind mount testdisk in container
	container_id=$(${cli} run -t -d \
			      --mount type=bind,source=${SHELLPACK_TEST_MOUNT},target=/testdisk \
			      ${image_id})
	echo "container_id: ${container_id}"
}

function prepare_mmtests() {
	echo "Copying and preparing mmtests"
	c_mmtests_dir=/$(basename ${SCRIPTDIR})

	${cli} cp ${SCRIPTDIR} ${container_id}:${c_mmtests_dir}
	${cli} exec -w ${c_mmtests_dir} ${container_id} \
	       sed -i -e 's/zypper install/zypper install -y/' bin/install-depends
	${cli} exec -w ${c_mmtests_dir} ${container_id} \
	       bin/install-depends awk gzip wget
	${cli} exec -w ${c_mmtests_dir} ${container_id} \
	       rm -rf work
	${cli} exec -w ${c_mmtests_dir} ${container_id} \
	       mkdir work
	# point to bind mounted testdisk
	${cli} exec -w ${c_mmtests_dir} ${container_id} \
	       ln -s /testdisk work/testdisk
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
	if [ -n "${image_id}" ]; then
		echo "Removing image ${image_id}"
		${cli} image rm ${image_id}
	fi
	if [ "${cli}" = "docker" ]; then
		echo "Stopping dockerd"
		pkill -SIGTERM dockerd
	fi
}

function main() {
	parse_args "$@"
	prolog
	check_os_version
	prepare_container_cli
	pull_image
	start_container
	prepare_mmtests
	run_mmtests
	copy_results
	stop_container
	cleanup_container_cli
}

main "$@"
