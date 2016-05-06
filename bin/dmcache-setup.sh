#!/bin/bash

# Author: Andreas Herrmann <aherrmann@suse.com>
# script to handle dmcache setup/removal/status

function err() {
    if [ $# -gt 1 ]; then
	local ret=${1}; shift
	echo "[$(date +"%F %H:%M:%S")] "$@ >&2
	exit ${ret}
    else
	echo "[$(date +"%F %H:%M:%S")] "$@ >&2
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

function parse_args() {
    local scriptname=$(basename $0) action_nr=0
    local opts=$(getopt -o hvadb:c:s:v --long attach,detach,backing-device: \
	--long block-size:,cache-mode:,caching-device:,caching-device-size: \
	--long dry-run,show-dev,status,verbose,help \
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
	    --block-size)
		block_size=${2}
		shift 2;;
	    --cache-mode)
		cache_mode=${2}
		shift 2;;
	    -c|--caching-device)
		caching_device=${2}
		shift 2;;
	    -s|--caching-device-size)
		caching_device_size=${2}
		shift 2;;
	    -d|--detach)
		action[${action_nr}]=detach
		action_nr=${action_nr}+1
		shift;;
	    --dry-run)
		dry_run=true
		shift 1;;
	    --status)
		action[${action_nr}]=status
		action_nr=${action_nr}+1
		shift;;
	    --show-dev)
		action[${action_nr}]=show-dev
		action_nr=${action_nr}+1
		shift;;
	    -v|--verbose)
		verbose=1
		shift;;
	    -h|--help) cat <<EOF
${scriptname} [OPTIONS]

dm-cache handling script. Calculate device sizes (for metadata and
data for cache device) and create command lines for dm-cache handling.

Options:

  -a, --attach        attach caching and backing device
  -c, --caching-device <dev>  device/partition to be used as caching device
  -b, --backing-device <dev>  device/partition to be used as backing device
    --block-size <size>  number of sectors to define cache block size
                         (must be between 64 and 2097152)
  -d, --detach        detach caching and backing device
    --dry-run         just print commands, don't execute
    --cache-mode <mode>  mode of cache device, one of:
                         [writeback],writethrough,writethrough,none
  -s, --caching-device-size <size>
                      use specified size for caching device
                      (instead of using entire device)
    --show-dev        print name of dm-cache device
    --status          print status for dm-cache device
  -v, --verbose       provide verbose output
  -h, --help          print this help text and exit

EOF
		shift; exit 0;;
	    *) break;;
	esac
    done
}

function dmcache_print_status() {
    local type
    info 1 "${1}"
    type=$(echo ${1} | awk '{ print $3 }')
    if [ "${type}" = "cache" ]; then
	# note that position are off-by-one as device prefix is added
	echo ${dm_cache_dev} ${1} \
	    | awk '{ {print \
		  "           device: " $1,$2,$3,$4 \
		"\n  metadata blocks: " $5,$6 \
		"\n     cache blocks: " $7,$8 \
		"\n read hits/misses: " $9,$10 \
		"\nwrite hits/misses: " $11,$12 \
		"\n   de/pro-motions: " $13,$14 \
		"\n     dirty blocks: " $15 \
		"\n    # of features: " $16  }
	{printf   "         features:"
	 for(i=17;i<=16+$16;i++){printf " %s", $i}; i=(17+$16)
	 printf "\n   # of core args: %s", $i; k=(i+1+$i)
	 printf "\n        core args:"; for(j=i+1;j<k;j++){printf " %s", $j}
	 printf "\n           policy: %s", $k; k=(k+1)
	 printf "\n # of policy args: %s", $k
	 printf "\n      policy args:";	for(j=k+1;j<=k+$k;j++){printf " %s", $j}
	 k=(k+$k+1)
	 printf "\n    metadata mode: %s", $k
	 printf "\n      needs check: %s", $(k+1)
	 printf "\n"}
	}'
    fi
}

function dmcache_status() {
    local state
    state=$(dmsetup status ${dm_cache_dev})
    dmcache_print_status "${state}"
}

function get_device_size() {
    # get size of entire device in bytes and check plausibility
    local t
    t=$(blockdev --getsize64 ${caching_device})
    if [ $? -gt 0 ]; then
	err 1 "blockdev --getsize64 ${caching_device} failed"
    fi
    caching_device_size=${caching_device_size:-${t}}
    if [ ${t} -gt ${caching_device_size} ]; then
	info "using cache-device-size (${caching_device_size} instead of ${t})"
    elif [ ${t} -lt ${caching_device_size} ]; then
	err 1 "cache-device-size > size of device (${caching_device_size} > ${t})"
    fi
    if [ ${caching_device_size} -lt ${min_dev_size} ]; then
	err 1 "device size too small"
    fi
    backing_device_size=$(blockdev --getsz ${backing_device})
    if [ $? -gt 0 ]; then
	err 1 "blockdev --getsize64 ${backing_device} failed"
    fi
}

function get_metadata_size() {
    # calculated according to
    # https://www.redhat.com/archives/dm-devel/2012-December/msg00046.html
    # 4 MB + ( 16 bytes * nr_blocks )
    info 1 "device size: ${caching_device_size}, \
	cache block size: ${cache_block_size}"
    metadata_size=$((4194304+(16*${caching_device_size}/${cache_block_size})))
    info 1 "metadata size: ${metadata_size}"
    metadata_sectors=$((${metadata_size}/${sector_size}+1))
    data_sectors=$((${caching_device_size}/${sector_size}-${metadata_sectors}))
    info 1 "metadata sectors: ${metadata_sectors}, data sectors: ${data_sectors}"
}

function check_physicalblock_size() {
    local pbsz
    pbsz=$(blockdev --getpbsz ${caching_device})
    if [ ${pbsz} -ne ${sector_size} ]; then
	err 1 "sector size mismatch (${caching_device}: ${sector_size} != ${pbsz})"
    fi
}

function dmcache_calculate_sizes() {
    get_device_size
    get_metadata_size
    check_physicalblock_size
}

function dmcache_setup_dm_device() {
    cmd "dmsetup create ${dm_meta_cdev} --table \"0 ${metadata_sectors} \
	linear ${caching_device} 0\""
    cmd "dd if=/dev/zero of=/dev/mapper/${dm_meta_cdev} bs=512 \
	count=${metadata_sectors}"
    cmd "dmsetup create ${dm_blck_cdev} --table \
	\"0 ${data_sectors} linear ${caching_device} ${metadata_sectors}\""
    cmd "dmsetup create ${dm_cache_dev} --table \"0 ${backing_device_size} \
	cache /dev/mapper/${dm_meta_cdev} /dev/mapper/${dm_blck_cdev} \
	${backing_device} ${block_size} 1 ${cache_mode} default 0\""
}

function dmcache_remove_dm_device() {
    local state dirty blksz
    state=$(dmsetup status ${dm_cache_dev})
    blksz=$(echo ${state} | awk '{ print $6 }')
    if [ ${blksz} -ne ${block_size} ]; then
	info "${state}"
	err 1 "cache block size mismatch (${blksz} != ${block_size})"
    fi
    info 1 "${state}"
    cmd "dmsetup suspend ${dm_cache_dev}"
    cmd "dmsetup reload ${dm_cache_dev} --table \"0 ${backing_device_size} \
	cache /dev/mapper/${dm_meta_cdev} /dev/mapper/${dm_blck_cdev} \
	${backing_device} ${block_size} 0 cleaner 0\""
    cmd "dmsetup resume ${dm_cache_dev}"
    state=$(dmsetup status ${dm_cache_dev})
    info 1 "${state}"
    dirty=$(echo ${state} | awk '{ print $14 }')
    if [ "${dirty:-0}" -gt 0 ]; then
	    info "${state}"
	    cmd "dmsetup wait ${dm_cache_dev}"
	    state=$(dmsetup status ${dm_cache_dev})
	    info "${state}"
    fi
    cmd "dmsetup suspend ${dm_cache_dev}"
    cmd "dmsetup clear ${dm_cache_dev}"
    cmd "dmsetup remove ${dm_cache_dev}"
    cmd "dmsetup remove ${dm_meta_cdev}"
    cmd "dmsetup remove ${dm_blck_cdev}"
}

function dmcache_show_dev() {
    local d=/dev/mapper/${dm_cache_dev}
    if [ ! -e ${d} ]; then
	err 1 "cache device ${d} doesn't exist"
    fi
    echo ${d}
}

function prolog () {
    if [ ${#action[*]} -eq 0 ]; then
	err 1 "no action specified"
    elif [ ${#action[*]} -gt 1 ]; then
	err 1 "multiple actions specified"
    fi

    if [ -z "${caching_device}"  ]; then
	err 1 "caching device not set"
    fi

    if [ -z "${backing_device}" ]; then
	err 1 "backing device not set"
    fi

    block_size=${block_size:-512}
    cache_mode=${cache_mode:-writeback}

    cdev=$(basename ${caching_device})
    bdev=$(basename ${backing_device})

    dm_meta_cdev=ssd-metadata-${cdev}
    dm_blck_cdev=ssd-blocks-${cdev}
    dm_cache_dev=cached_device-${cdev}-${bdev}

    sector_size=512
    local min_block_size=64
    local max_block_size=2097152
    if [ ${block_size} -lt ${min_block_size} \
	-o ${block_size} -gt ${max_block_size} ]; then
	err 1 "block_size (${block_size}) out of range \
	[${min_block_size}, ${max_block_size}]"
    else
	local t=$((${block_size}/64))
	local t1=$((${t}*64))
	if [ ${block_size} -ne ${t1} ]; then
	    err 1 "error block_size (${block_size}) no multiple of 64"
	fi
	cache_block_size=$((${block_size}*512))
    fi
    # to be on safe side: 1 cache block + 1 sector
    # 4MB + 16 + <cache block size> + 512
    local mb=1048576
    min_dev_size=$((4*${mb} + 16 + ${cache_block_size} + 512))
    info 1 "min-dev-size: ${min_dev_size}"
}

function main() {
	parse_args "$@"
	prolog

	case "${action[0]}" in
	    attach)
		dmcache_calculate_sizes
		dmcache_setup_dm_device
		;;
	    detach)
		dmcache_calculate_sizes
		dmcache_remove_dm_device
		;;
	    show-dev)
		dmcache_show_dev
		;;
	    status)
		dmcache_status
		;;
	    *) ;;
	esac
}

main "$@"
