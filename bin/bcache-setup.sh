#!/bin/bash

# Author: Andreas Herrmann <aherrmann@suse.com>
# script to handle bcache creation/removal
#
# TODO:
# - parameters to pass fixed size for caching device (e.g. to lower
#   size for use with small backing store)
# - support multiple backing devices
# - support make-bcache option "-b bucket-size", e.g. 256k (defaults to 128k)

function err() {
    if [ $# -gt 1 ]; then
	local ret=${1}; shift
	echo "[$(date +"%F %H:%M:%S")] $@" >&2
	exit ${ret}
    else
	echo $@
    fi
}

function info() {
    if [ $# -gt 1 ]; then
	if [ ${1} -le ${verbose:=0} ]; then
	    shift; echo $@
	fi
    else
	echo $@
    fi
}

function cmd() {
    if [ "${dry_run:=false}" = "true" ]; then
	info "$@"
    else
	info 1 "$@"
	eval $@
    fi
}

function show_attribs() {
    local i t
    for i in $(find ${1} -maxdepth 1 -type f); do
	t=$(basename $(dirname $(dirname ${i})))
	printf "%-5.5s: %-27.27s: " ${t}  $(basename ${i})
	cat ${i}
    done
}

function parse_args() {
    local scriptname=$(basename $0) action_nr=0
    local opts=$(getopt -o hab:c:drsv --long attach,detach,backing-device: \
	--long cache-mode:,caching-device:,dry-run,register,show-dev,status \
	--long stop,verbose,help \
	-n \'${scriptname}\' -- "$@")
    eval set -- "${opts}"

    while true; do
	case "${1}" in
	    -a|--attach)
		action[${action_nr}]=attach
		action_nr=${action_nr}+1
		shift;;
	    -b|--backing-device)
		backing_device=${2}
		shift 2;;
	    --cache-mode)
		cache_mode=${2}
		shift 2;;
	    -c|--caching-device)
		caching_device=${2}
		shift 2;;
	    -d|--detach)
		action[${action_nr}]=detach
		action_nr=${action_nr}+1
		shift;;
	    --dry-run)
		dry_run=true
		shift 1;;
	    -r|--register)
		action[${action_nr}]=register
		action_nr=${action_nr}+1
		shift;;
	    --show-dev)
		action[${action_nr}]=show-dev
		action_nr=${action_nr}+1
		shift;;
	    --status)
		action[${action_nr}]=status
		action_nr=${action_nr}+1
		shift;;
	    -s|--stop)
		action[${action_nr}]=stop
		action_nr=${action_nr}+1
		shift;;
	    -v|--verbose)
		verbose=1
		shift;;
	    -h|--help) cat <<EOF
${scriptname} [OPTIONS]

Bcache handling script.

Options:

  -a, --attach        attach (ie. register) caching device to backing device
  -c, --caching-device <dev>  device/partition to be used as caching device
  -b, --backing-device <dev>  device/partition to be used as backing device
  -d, --detach        detach caching device from backing device and close
                      caching device (ie. it uses unregister bcache attribute)
    --dry-run         just print commands, don't execute
    --cache-mode <mode>  mode of cache device, one of:
                         [writeback],writethrough,writethrough,none
  -r, --register      register backing_device
    --show-dev        print name of bcache device
    --status          print status for bcache device
  -s, --stop          stop and close backing_device
  -v, --verbose	      provide verbose output
  -h, --help          print this help text and exit

EOF
		shift; exit 0;;
	    *) break;;
	esac
    done
}

function bcache_status() {
    echo -e "bcache status:"
    local sfile sdir
    sfile=$(find /sys -path "*/${bdev}/*" -name "cache_mode")
    sdir=$(dirname ${sfile})
    show_attribs ${sdir}/cache_mode
    show_attribs ${sdir}/state
    show_attribs ${sdir}/stats_total
}

function bcache_stop() {
    # shut down bcache device and close backing device
    local dev sfile
    dev=$(basename ${backing_device})
    sfile=$(find /sys -path "*/${dev}/bcache/stop")
    if [ "${sfile}" = "" ]; then
	err 1 "device ${backing_device} not registered"
    fi
    cmd "echo 1 > ${sfile}"
}

function bcache_detach() {
    # detach caching device from backing device and close caching device
    local cset_uuid
    cset_uuid=$(bcache-super-show ${caching_device} | \
	grep "^cset.uuid" | awk '{print $2}')
    if [ -e /sys/fs/bcache/${cset_uuid} ]; then
	info 1 "unregistering ${caching_device} (cset.uuid=${cset_uuid})"
	cmd "echo 1 > /sys/fs/bcache/${cset_uuid}/unregister"
	sleep 3
    fi
}

function bcache_make_cdev() {
    # create caching device
    local cset_uuid i
    cset_uuid=$(bcache-super-show ${caching_device} | \
	grep "^cset.uuid" | awk '{print $2}')
    if [ -e /sys/fs/bcache/${cset_uuid} ]; then
	for i in 2 4 8 16 32 64; do
	    err "device ${caching_device} still registered, waiting ${i} seconds"
	    sleep ${i}
	    if [ -e /sys/fs/bcache/${cset_uuid} ]; then
		continue
	    else
		break
	    fi
	done
	if [ -e /sys/fs/bcache/${cset_uuid} ]; then
	    err "device $caching_device (${cset_uuid}) still registered, aborting"
	    exit 1
	fi
    fi
    cmd "wipefs -a ${caching_device}"
    cmd "make-bcache -C ${caching_device}"
    cmd "echo ${caching_device} > /sys/fs/bcache/register"
}

function bcache_attach() {
    # attach caching device to backing device
    bcache_make_cdev

    local sfile dev cset_uuid
    cset_uuid=$(bcache-super-show ${caching_device} | \
	grep "^cset.uuid" | awk '{print $2}')
    dev=$(basename ${backing_device})
    sfile=$(find /sys -path "*/${dev}/bcache/attach")
    if [ ! -e "${sfile}" ]; then
	err "backing device ${backing_device} not registered"
	bcache_detach
	exit 1
    fi
    cmd "echo ${cset_uuid} > ${sfile}"

    sfile=$(find /sys -path "*/${dev}/bcache/cache_mode")
    cmd "echo ${cache_mode:-writeback} > ${sfile}"
}

function bcache_make_bdev() {
    # create backing device
    local dev sfile
    dev=$(basename ${backing_device})
    sfile=$(find /sys -path "*/${dev}/bcache/stop")
    if [ -e "${sfile}" ]; then
	err "backing device ${backing_device} still registered"
	exit 1
    fi

    cmd "wipefs -a ${backing_device}"
    cmd "make-bcache -B ${backing_device}"
    cmd "echo ${backing_device} > /sys/fs/bcache/register"
}

function bcache_register() {
    # register backing device
    bcache_make_bdev
}

function bcache_show_dev() {
    local sfile
    sfile=$(find /sys -path "*/${bdev}/*" -name "bcache[0-9]*")
    if [ ! -e "${sfile}" ]; then
	err 1 "no bcache device found for ${backing_device}"
    fi
    d=/dev/$(basename ${sfile})
    if [ ! -e ${d} ]; then
	err 1 "cache device ${d} doesn't exist"
    fi
    echo ${d}
}

function prolog() {
    if [ ${#action[*]} -eq 0 ]; then
	err 1 "no action specified"
    elif [ ${#action[*]} -gt 1 ]; then
	err 1 "multiple actions specified"
    fi
    cache_mode=${cache_mode:-writeback}
    bdev=$(basename ${backing_device})
}

function main() {
	parse_args "$@"
	prolog
	case "${action[0]}" in
	    attach)
		if [ -z "${caching_device}"  ]; then
		    err 1 "caching device not set"
		fi
		if [ -z "${backing_device}" ]; then
		    err 1 "backing device not set"
		fi
		bcache_attach
		;;
	    detach)
		if [ -z "${caching_device}" ]; then
		    err 1 "caching device not set"
		fi
		bcache_detach
		;;
	    register)
		if [ -z "${backing_device}" ]; then
		    err 1 "backing device not set"
		fi
		bcache_register
		;;
	    show-dev)
		bcache_show_dev
		;;
	    stop)
		if [ -z "${backing_device}" ]; then
		    err 1 "backing device not set"
		fi
		bcache_stop
		;;
	    status)
		bcache_status
		;;
	    *) ;;
	esac
}

main "$@"
