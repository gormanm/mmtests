LIBHUGETLBFS_ROOT=$SHELLPACK_SOURCES/libhugetlbfs-${LIBHUGETLBFS_VERSION}-installed
LIBHUGETLBFS_LD=$LIBHUGETLBFS_ROOT/share/libhugetlbfs
LIBHUGETLBFS_LIBPATH=$LIBHUGETLBFS_ROOT/lib:$LIBHUGETLBFS_ROOT/lib64
LIBHUGETLBFS_LINK_OPTIONS="-B $LIBHUGETLBFS_LD -Wl,--hugetlbfs-link=BDT -Wl,--library-path=$LIBHUGETLBFS_ROOT/lib -Wl,--library-path=$LIBHUGETLBFS_ROOT/lib64"

# Check if libhugetlbfs needs to be installed
if [ "$USE_LARGE_PAGES" = "yes" -a ! \( -f $LIBHUGETLBFS_ROOT/lib/libhugetlbfs.so \) ]; then
	unset DATS_FUNCTIONS_SOURCED
	$SHELLPACK_INCLUDE/shellpack-install-libhugetlbfsbuild -v $LIBHUGETLBFS_VERSION || die Failed to install libhugetlbfs
fi
