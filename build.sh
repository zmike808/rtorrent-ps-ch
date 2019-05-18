#! /usr/bin/env bash
#
<<<<<<< HEAD
# Build optimized version of rTorrent/libTorrent including patches into custom location
#   project URL: https://github.com/chros73/rtorrent-ps-ch


# Set rT-PS-CH version
rt_ps_ch_major_version='1.8'
rt_ps_ch_minor_release='3'
rt_ps_ch_minor_git='3'

# Set latest major libTorrent/rTorrent release versions
lt_major='0.13'
rt_major='0.9'
rt_minor='7'

# Specify git branch/commit for libTorrent/rTorrent to compile from: [master|15e64bd]
git_lt='ef1e7c0'                # 2018-06-07 master v0.13.7
git_rt='327164f'                # 2018-06-07 master v0.9.7

# Dependency versions
cares_version='1.14.0'          # 2018.02.16
curl_version='7.61.1'           # 2018.09.05 ; WARNING: see rT issue #457 regarding curl configure options
xmlrpc_tree='stable'            # [super-stable | stable | advanced]
xmlrpc_rev='2985'               # 2018.04.08 v1.43.07
export cares_version curl_version xmlrpc_tree xmlrpc_rev

=======
# Build rpath-linked rTorrent including patches and dependencies.
#
# Patches Explained
# -----------------
#
# In the 'extend' action, the release tarballs are unpacked and
# then all relevant patches are applied before compiling.
#
# The lt-ps/ps patches are feature additions, or bug fixes developed
# originally for rTorrent-PS, that change the core code.
#
# The backport patch file names can contain several version numbers,
# namely those versions they apply to.
#
# libtorrent patches:
#   * lt-ps-*_{0.13.N,all}.patch
#   * backport*_0.13.N_*.patch
#   * the 'LT_PATCHES' array (conditional patches)
#   * 'LT_BASE_PATCHES' also apply to vanilla builds
#   * note that all of these patches ALSO influence the vanilla version
#     at runtime (via dynamic linking)
#
# rtorrent patches:
#   * ps-*_{0.9.N,all}.patch
#   * backport*_0.9.N_*.patch
#   * the 'RT_PATCHES' array (conditional patches)
#   * 'RT_BASE_PATCHES' also apply to vanilla builds
#
# Original PyroScope patches (new commands and canvas):
#   * pyroscope.patch
#   * ui_pyroscope.patch
#
# Patches that contain neither a LT/RT version or 'all' are ones
# added dynamically in the build script (e.g. platform-specific ones).
#
# Note that patches are only tested for the current stable release,
# so older versions might get regressions over time (failing patches).

# Get git metadata
if test ! -d .git -a -f docker-env; then
    . docker-env
else
    git_stamp_iso="$(stat -c '%y' * | sed -re 's/(.+) (..):(..).+/\1-\2\3/' | sort -u | tail -n1)"
    git_id="$(git describe --long --tags --dirty="-$git_stamp_iso")"
    git_commits_since_release=$(sed -re 's/.+-([0-9]+)-g[0-9a-fA-F]{7}.*/\1/' <<<"$git_id")
fi

# Version selection
export RT_MINOR=6
export LT_VERSION=0.13.$RT_MINOR; export RT_VERSION=0.9.$RT_MINOR;
export GIT_MINOR=$(( $RT_MINOR + 1 ))  # ensure git version has a bumped version number
export VERSION_EXTRAS=" $git_id"

export RT_PS_REVISION="${git_id%%-$git_commits_since_release-g*}"
if test "$git_commits_since_release" -eq 0; then
    VERSION_EXTRAS=" ${RT_PS_REVISION}-0"
else
    RT_PS_REVISION="${RT_PS_REVISION%.*}.$(( ${RT_PS_REVISION##*.} + 1 ))-dev"
fi

# List of platforms to build DEBs for with "docker_deb all|stable|oldstable"
docker_distros_stable=(
    debian:stretch
    ubuntu:bionic
)
docker_distros_oldstable=(
    debian:jessie
    ubuntu:xenial
)
docker_distros_all=()
docker_distros_all+=( "${docker_distros_stable[@]}" )
docker_distros_all+=( "${docker_distros_oldstable[@]}" )
docker_distros_all+=(
    debian:wheezy
    ubuntu:trusty
    ubuntu:precise
)

# Debian-like deps, see below for other distros
BUILD_PKG_DEPS=( libncurses5-dev libncursesw5-dev libssl-dev zlib1g-dev libcppunit-dev locales )

# Fitting / tested dependency versions for major platforms
#export CARES_VERSION=1.13.0 # 2017-06
#export CURL_VERSION=7.54.1  # 2017-06
#export XMLRPC_REV=2917      # Release 1.48.00 2016-12-27
export CARES_VERSION=1.14.0 # 2018-02
export CURL_VERSION=7.61.0  # 2018-07
export XMLRPC_REV=2954      # Release 1.49.02 2017-09

# Extra options handling (set overridable defaults)
: ${PACKAGE_ROOT:=/opt/rtorrent}
: ${INSTALL_ROOT:=$HOME}
: ${INSTALL_DIR:=$INSTALL_ROOT/.local/rtorrent/$RT_VERSION-$RT_PS_REVISION}
: ${BIN_DIR:=$INSTALL_ROOT/bin}
: ${CURL_OPTS:=-sLS}
: ${MAKE_OPTS:=-j4}
: ${CFG_OPTS:=}
: ${CFG_OPTS_LT:=}
: ${CFG_OPTS_RT:=}
export PACKAGE_ROOT INSTALL_ROOT INSTALL_DIR BIN_DIR CURL_OPTS MAKE_OPTS CFG_OPTS CFG_OPTS_LT CFG_OPTS_RT

export SRC_DIR=$(cd $(dirname $0) && pwd)
LT_PATCHES=( )
RT_PATCHES=( )
LT_BASE_PATCHES=( $SRC_DIR/patches/lt-base-cppunit-pkgconfig.patch )
RT_BASE_PATCHES=( $SRC_DIR/patches/rt-base-cppunit-pkgconfig.patch )

# Distro specifics
case $(echo -n "$(lsb_release -sic 2>/dev/null || echo NonLSB)" | tr ' \n' '-') in
    *-precise|*-trusty|*-utopic|*-wheezy)
        ;;
    *-jessie)
        ;;
    *-vivid|*-wily|*-xenial|*-yakkety|*-zesty)
        ;;
    *-stretch|Fedora-TwentySix)
        ;;
    *-buster)
        BUILD_PKG_DEPS+=( gcc-7 g++-7 )
        export CC=gcc-7 CXX=g++-7
        ;;
    Arch-*) # 0.9.[46] only!
        BUILD_PKG_DEPS=( ncurses openssl cppunit )
        source /etc/makepkg.conf 2>/dev/null
        MAKE_OPTS="${MAKEFLAGS}${MAKE_OPTS:+ }${MAKE_OPTS}"
        ;;
    NonLSB)
        # Place tests for MacOSX etc. here
        BUILD_PKG_DEPS=( )
        echo
        echo "*** Build dependencies are NOT pre-checked on this platform! ***"
        echo
        ;;
esac

# OpenSSL version detection for selective patching
case $(openssl version 2> /dev/null | egrep -o "1.[0-9].[0-9]+") in
    1.1.*)
        LT_BASE_PATCHES+=( $SRC_DIR/patches/lt-open-ssl-1.1.patch )
        ;;
esac

# GCC and C++ standards:
#   -std=c++17 / gnu++17    EXPERIMENTAL in GCC 5 and later
#   -std=c++14 / gnu++14    Default in GCC 6.1+
#   -std=c++11 / gnu++11    GCC 4.8.1+ supports all MAJOR features
#   -std=c++0x              Older name for C++11
#   -std=c++98              Default before GCC 6.1
#   [https://gcc.gnu.org/projects/cxx-status.html]
#
# Ubuntu versions:
#   precise (12.04) 4.6.3
#   trusty  (14.04) 4.8.2
#   xenial  (16.04) 5.3.1
#   bionic  (18.04) 7.3.0
#
# Try this when you get configure errors regarding xmlrpc-c
# ... on a Intel PC type system with certain types of CPUs:
#export CFLAGS="$CFLAGS -march=i586"
export USE_CXXFLAGS=true
GCC_DOT_VER=$(gcc --version 2>/dev/null | head -n1 | cut -d' ' -f4)
GCC_INT_VER=$(printf "%d%02d%02d" $(tr . ' ' <<<$GCC_DOT_VER))

if command which dpkg-architecture >/dev/null && dpkg-architecture -earmhf; then
    GCC_TYPE="Raspbian"
elif command which gcc >/dev/null; then
    GCC_TYPE=$(gcc --version | head -n1 | tr -s '()' ' ' | cut -f2 -d' ')
else
    GCC_TYPE=none
fi

# Fix libtorrent bug with gcc version >= 6 and non-empty CXXFLAGS env var
test "${GCC_INT_VER:-0}" -ge 60000 && export USE_CXXFLAGS=false || :

# Set C++ standard support
cpp_std=""
test "${GCC_INT_VER:-0}" -ge 40300 && cpp_std="-std=c++0x" || :
test "${GCC_INT_VER:-0}" -ge 40801 && cpp_std="-std=c++11" || :
grep -- '-std=' <<<"$CPPFLAGS" >/dev/null || export CPPFLAGS="${CPPFLAGS}${cpp_std:+ }${cpp_std}"

case "$GCC_TYPE" in
    # Raspberry Pi 2 with one of
    #   gcc (Debian 4.6.3-14+rpi1) 4.6.3
    #   gcc (Raspbian 4.8.2-21~rpi3rpi1) 4.8.2
    Raspbian)
        if uname -a | grep 'armv7' >/dev/null; then
            export CFLAGS="$CFLAGS -march=armv7-a -mfpu=neon-vfpv4 -mfloat-abi=hard"
            export CFG_OPTS_LT="$CFG_OPTS_LT --disable-instrumentation"
        fi
        ;;
esac
>>>>>>> upstream/master


#
# HERE BE DRAGONS!
#

set -e
set +x

# Extra options handling (overridable defaults)
: ${curl_opts:='-sLS'}
: ${cfg_opts:=}
: ${cfg_opts_lt:=}
: ${cfg_opts_rt:=}
: ${check_hash_packages:='yes'}
: ${patch_build:='yes'}
: ${optimize_build:='yes'}
[[ "$optimize_build" = 'yes' ]] && : ${make_opts:='-j4'}
: ${build_root:="$HOME"}
: ${root_sys_dir:='/usr/local'}
: ${root_pkg_dir:='/opt'}
: ${ver_info_filename:='version-info.sh'}
export curl_opts cfg_opts cfg_opts_lt cfg_opts_rt make_opts


# Support only git versions of lT/rT (not major releases)
only_git_lt_rt=false

# Set main lT/rT variables
rt_ps_ch_version="$rt_ps_ch_major_version.$rt_ps_ch_minor_release"
lt_version="$lt_major.$rt_minor"
rt_version="$rt_major.$rt_minor"
lt_down_version="$lt_version"
rt_down_version="$rt_version"

# Let's fake the version number of the git version to be compatible with our patching system
git_minor="$[$rt_minor + 1]"

set_git_env_vars() { # Reset lT/rT env vars if git is used
    rt_ps_ch_version="$rt_ps_ch_major_version.$rt_ps_ch_minor_git"
    lt_version="$lt_major.$git_minor"
    rt_version="$rt_major.$git_minor"
    lt_down_version="$git_lt"
    rt_down_version="$git_rt"
}

# Only support git versions or dealing with optional 2nd "git" argument: update necessary variables
[[ "$only_git_lt_rt" = true ]] || [[ "$2" = 'git' ]] && set_git_env_vars
export lt_version rt_version


# rT-PS-CH variables
rt_ps_ch_title='rTorrent-PS-CH'
rt_ps_ch_dirname="$(echo "$rt_ps_ch_title" | tr '[:upper:]' '[:lower:]')"

# Main directory declarations
build_dir="$build_root/lib/$rt_ps_ch_dirname-$rt_ps_ch_version-$rt_version"
root_symlink_dir="$root_pkg_dir/$rt_ps_ch_dirname"
pkg_inst_dir="$root_symlink_dir-$rt_ps_ch_version-$rt_version"
dist_dir="/tmp/$rt_ps_ch_dirname-dist"
src_dir="$(cd $(dirname "$0") && pwd)"
tarballs_dir="$src_dir/tarballs"
export build_dir tarballs_dir


reset_vanilla_env_vars() { # Reset necessary vars for vanilla build
    vanilla_postfix='-vanilla'
    rt_ps_ch_dirname="$rt_ps_ch_dirname${vanilla_postfix}"
    build_dir="$build_root/lib/$rt_ps_ch_dirname-$rt_ps_ch_version-$rt_version"
}


# Fix people's broken systems
[[ "$(tr 'A-Z' 'a-z' <<<"${LANG/*.}")" = 'utf-8' ]] || export LANG='en_US.UTF-8'
unset LC_ALL
export LC_ALL

<<<<<<< HEAD
# Select build tools (prefer 'g' variants if available)
command which gmake &>/dev/null && export make_bin='gmake' || export make_bin='make'
command which glibtoolize &>/dev/null && libtoolize_bin='glibtoolize' || libtoolize_bin='libtoolize'


# Debian-like deps, see below for other distros
build_pkg_deps=('libncurses5-dev' 'libncursesw5-dev' 'libssl-dev' 'zlib1g-dev' 'libcppunit-dev' 'locales')


# Distro specifics
case "$(echo -n "$(lsb_release -sic 2>/dev/null || echo NonLSB)" | tr ' \n' '-')" in	#"
    Arch-*) # 0.9.[46] only!
        build_pkg_deps=( ncurses openssl cppunit )
        source /etc/makepkg.conf 2>/dev/null
        make_opts="${MAKEFLAGS}${make_opts:+ }${make_opts}"
        ;;
    NonLSB) # Place tests for MacOSX etc. here
        build_pkg_deps=( )
        echo
        echo "*** Build dependencies are NOT pre-checked on this platform! ***"
        echo
        ;;
esac


# Set sed command
sed_i="sed -i -e"
=======
# Select build tools (prefer 'g' variants if there)
command which gmake >/dev/null && export MAKE=gmake || export MAKE=make
command which glibtoolize >/dev/null && export LIBTOOLIZE=glibtoolize || export LIBTOOLIZE=libtoolize
>>>>>>> upstream/master

# Platform magic
case "$(uname -s)" in
    FreeBSD)
<<<<<<< HEAD
        sed_i="sed -i '' -e"
        ;;
esac


# Check gcc type
gcc_type='none'

if command which dpkg-architecture &>/dev/null && dpkg-architecture -earmhf; then
    gcc_type='raspbian'
elif command which gcc &>/dev/null; then
    gcc_type="$(gcc --version | head -n1 | tr -s '()' ' ' | cut -f2 -d' ')"
fi

# gcc optimization
case "$gcc_type" in
    raspbian)
        # Raspberry Pi 2 with one of
        #   gcc (Debian 4.6.3-14+rpi1) 4.6.3
        #   gcc (Raspbian 4.8.2-21~rpi3rpi1) 4.8.2
        if uname -a | grep 'armv7' &>/dev/null; then
            export CFLAGS="-march=armv7-a -mfpu=neon-vfpv4 -mfloat-abi=hard -O2 -fomit-frame-pointer${CFLAGS:+ }${CFLAGS}"
            export cfg_opts_lt="$cfg_opts_lt --disable-instrumentation"
            optimize_build='yes'
        fi
        ;;
    *)
        [[ "$optimize_build" = 'yes' ]] && export CFLAGS="-march=native -pipe -O2 -fomit-frame-pointer${CFLAGS:+ }${CFLAGS}"
        ;;
esac


set_compiler_flags() { # Set final compiler flags
    export PKG_CONFIG_PATH="$build_dir/lib/pkgconfig${PKG_CONFIG_PATH:+:}${PKG_CONFIG_PATH}"
    export LDFLAGS="-Wl,-rpath,'\$\$ORIGIN/../lib' -Wl,-rpath,'\$\$ORIGIN/../lib/$rt_ps_ch_dirname/lib'${LDFLAGS:+ }${LDFLAGS}"
    [[ -z "${CXXFLAGS+x}" ]] && [[ -z "${CFLAGS+x}" ]] || \
        export CXXFLAGS="${CFLAGS}${CXXFLAGS:+ }${CXXFLAGS}"
}


display_env_vars() { # Display env vars
    echo
    echo "${bold}Env for building $rt_ps_ch_title${vanilla_postfix} $rt_ps_ch_version $rt_version/$lt_version into $build_dir${off}"
    echo
    printf 'optimize_build="%s"\n'            "${optimize_build}"
    printf 'export PKG_CONFIG_PATH="%s"\n'    "${PKG_CONFIG_PATH}"
    printf 'export LDFLAGS="%s"\n'            "${LDFLAGS}"
    [[ -z "${CFLAGS+x}" ]] || \
        printf 'export CFLAGS="%s"\n'         "${CFLAGS}"
    [[ -z "${CXXFLAGS+x}" ]] || \
        printf 'export CXXFLAGS="%s"\n'       "${CXXFLAGS}"
    echo
    printf 'export build_dir="%s"\n'          "${build_dir}"
    printf 'pkg_inst_dir="%s"\n'              "${pkg_inst_dir}"
    echo
    printf 'export curl_opts="%s"\n'          "${curl_opts}"
    printf 'export make_opts="%s"\n'          "${make_opts}"
    printf 'export cfg_opts="%s"\n'           "${cfg_opts}"
    printf 'export cfg_opts_lt="%s"\n'        "${cfg_opts_lt}"
    printf 'export cfg_opts_rt="%s"\n'        "${cfg_opts_rt}"
    echo
}



# Sources
tarballs=("http://c-ares.haxx.se/download/c-ares-$cares_version.tar.gz")
tarballs+=("http://curl.haxx.se/download/curl-$curl_version.tar.gz")
tarballs+=("https://dl.bintray.com/chros73/$rt_ps_ch_dirname/pool/x/xmlrpc-c-$xmlrpc_tree/xmlrpc-c-$xmlrpc_tree-$xmlrpc_rev-src.tgz")
tarballs+=("https://github.com/rakshasa/rtorrent/releases/download/v$rt_version/libtorrent-$lt_version.tar.gz")
tarballs+=("https://github.com/rakshasa/rtorrent/releases/download/v$rt_version/rtorrent-$rt_version.tar.gz")

# Get xmlrpc-c from svn if it's not mirrored
[[ ! "$xmlrpc_rev" =~ ^(2985|2912|2775)$ ]] && xmlrpc_svn_url="http://svn.code.sf.net/p/xmlrpc-c/code/$xmlrpc_tree@$xmlrpc_rev"


# Source package md5 hashes
src_pkg_hashes=('c-ares-1.13.0.tar.gz:d2e010b43537794d8bedfb562ae6bba2')
src_pkg_hashes+=('c-ares-1.14.0.tar.gz:e57b37a7c46283e83c21cde234df10c7')
src_pkg_hashes+=('curl-7.54.1.tar.gz:21a6e5658fd55103a90b11de7b2a8a8c')
src_pkg_hashes+=('curl-7.60.0.tar.gz:48eb126345d3b0f0a71a486b7f5d0307')
src_pkg_hashes+=('curl-7.61.1.tar.gz:4762f41ef0dba751d1c7a3060a1c6ec6')
src_pkg_hashes+=('xmlrpc-c-stable-2912-src.tgz:d6336bc1ff6d5ba705438bed72268701')
src_pkg_hashes+=('xmlrpc-c-stable-2985-src.tgz:0784b5c41440e7451720cff316a64d80')
src_pkg_hashes+=('libtorrent-0.13.6.tar.gz:66f18044432a62c006c75f6d0bb4d7dc')
src_pkg_hashes+=('libtorrent-c167c5a.tar.gz:58448dbefe92616f6ad19ac41315feed')
src_pkg_hashes+=('libtorrent-0.13.7.tar.gz:fe34521cd440910b7ad4e1720a1ff5e0')
src_pkg_hashes+=('libtorrent-ef1e7c0.tar.gz:01720f250ca017a07e3c4d8378a992d5')
src_pkg_hashes+=('rtorrent-0.9.6.tar.gz:5e7550f74e382a6245412c615f45444d')
src_pkg_hashes+=('rtorrent-226e670.tar.gz:a0138f4739d4313d5dfad0432cabef5c')
src_pkg_hashes+=('rtorrent-0.9.7.tar.gz:284b833794ce3ab4ddc62cf1a20edeb1')
src_pkg_hashes+=('rtorrent-327164f.tar.gz:84944d3a23eeed5f4346b76d174e74e7')


# Directory definitions
sub_dirs="c-ares-*[0-9] curl-*[0-9] xmlrpc-c-$xmlrpc_tree-$xmlrpc_rev libtorrent-*[0-9] rtorrent-*[0-9]"


# Command dependency
build_cmd_deps=('coreutils:md5sum')
build_cmd_deps+=('curl:curl')
build_cmd_deps+=('subversion:svn')
build_cmd_deps+=("build-essential:$make_bin")
build_cmd_deps+=('build-essential:g++')
build_cmd_deps+=('patch:patch')
build_cmd_deps+=("libtool:$libtoolize_bin")
build_cmd_deps+=('automake:aclocal')
build_cmd_deps+=('autoconf:autoconf')
build_cmd_deps+=('automake:automake')
build_cmd_deps+=('pkg-config:pkg-config')
build_cmd_deps+=('chrpath:chrpath')


esc="$(echo -en \\0033)"
bold="$esc[1m"
off="$esc[0m"

=======
        export CFLAGS="-pipe -O2 -pthread${CFLAGS:+ }${CFLAGS}"
        export LDFLAGS="-s -lpthread${LDFLAGS:+ }${LDFLAGS}"
        export SED_I="sed -i '' -e"
        ;;
    Linux)
        export CPPFLAGS="-pthread${CPPFLAGS:+ }${CPPFLAGS}"
        export LIBS="-lpthread${LIBS:+ }${LIBS}"
        ;;
esac

# Keep rTorrent version, once it was built in this directory
# (this list also can be considered 'supported' versions,
# though only the last stable is regularly compiled)
test -d rtorrent-0.9.4 && { export LT_VERSION=0.13.4; export RT_VERSION=0.9.4; }
test -d rtorrent-0.9.5 && { export LT_VERSION=0.13.5; export RT_VERSION=0.9.5; }
test -d rtorrent-0.9.6 && { export LT_VERSION=0.13.6; export RT_VERSION=0.9.6; }
BUILD_GIT=false


set_build_env() {
    export CPPFLAGS="-I $INSTALL_RELEASE_DIR/include${CPPFLAGS:+ }${CPPFLAGS}"
    export CXXFLAGS="$CFLAGS"
    export LDFLAGS="-L$INSTALL_RELEASE_DIR/lib${LDFLAGS:+ }${LDFLAGS}"
    export LDFLAGS="-Wl,-rpath,$INSTALL_RELEASE_DIR/lib ${LDFLAGS}"
    export LIBS="${LIBS}"
    export PKG_CONFIG_PATH="$INSTALL_RELEASE_DIR/lib/pkgconfig${PKG_CONFIG_PATH:+:}${PKG_CONFIG_PATH}"

    local git_tag=''
    if $BUILD_GIT; then
        git_tag=' [GIT]'

        CPPFLAGS="-I $INSTALL_DIR/include${CPPFLAGS:+ }${CPPFLAGS}"
        LDFLAGS="-L$INSTALL_DIR/lib${LDFLAGS:+ }${LDFLAGS}"
        PKG_CONFIG_PATH="$INSTALL_DIR/lib/pkgconfig${PKG_CONFIG_PATH:+:}${PKG_CONFIG_PATH}"
    fi

    echo "!!! Installing rTorrent$VERSION_EXTRAS v$RT_VERSION$git_tag into $INSTALL_DIR !!!"; echo

    printf "export CPPFLAGS=%q\n"           "${CPPFLAGS}"
    printf "export CXXFLAGS=%q # use=%s\n"  "${CXXFLAGS}" "${USE_CXXFLAGS}"
    printf "export LDFLAGS=%q\n"            "${LDFLAGS}"
    printf "export LIBS=%q\n"               "${LIBS}"
    printf "export PKG_CONFIG_PATH=%q\n"    "${PKG_CONFIG_PATH}"
}

SELF_URL=https://github.com/pyroscope/rtorrent-ps.git
XMLRPC_URL="http://svn.code.sf.net/p/xmlrpc-c/code/advanced@$XMLRPC_REV"
TARBALLS=(
"http://c-ares.haxx.se/download/c-ares-$CARES_VERSION.tar.gz"
"http://curl.haxx.se/download/curl-$CURL_VERSION.tar.gz"
)

XMLRPC_SVN=true
case $XMLRPC_REV in
    2954|2917|2775|2626|2366)
        # XMLRPC_REV=2954; tar -cvz --exclude .svn -f xmlrpc-c-advanced-$XMLRPC_REV-src.tgz xmlrpc-c-advanced-$XMLRPC_REV
        TARBALLS+=( "https://bintray.com/artifact/download/pyroscope/rtorrent-ps/xmlrpc-c-advanced-$XMLRPC_REV-src.tgz" )
        XMLRPC_SVN=false
        ;;
esac

# Other sources:
#   http://rtorrent.net/downloads/
#   http://pkgs.fedoraproject.org/repo/pkgs/libtorrent/
#   http://pkgs.fedoraproject.org/repo/pkgs/rtorrent/
TARBALLS+=(
"https://bintray.com/artifact/download/pyroscope/rtorrent-ps/libtorrent-$LT_VERSION.tar.gz"
"https://bintray.com/artifact/download/pyroscope/rtorrent-ps/rtorrent-$RT_VERSION.tar.gz"
)

BUILD_CMD_DEPS=$(cat <<.
curl:curl
subversion:svn
build-essential:$MAKE
build-essential:g++
patch:patch
libtool:$LIBTOOLIZE
automake:aclocal
autoconf:autoconf
automake:automake
pkg-config:pkg-config
.
)

set -e
set +x
SUBDIRS="c-ares-*[0-9] curl-*[0-9] xmlrpc-c-advanced-$XMLRPC_REV libtorrent-*[0-9] rtorrent-*[0-9]"
ESC=$(echo -en \\0033)
BOLD="$ESC[1m"
OFF="$ESC[0m"

echo "${BOLD}Environment for building rTorrent$VERSION_EXTRAS $RT_VERSION/$LT_VERSION$OFF"
printf 'export PACKAGE_ROOT=%q\n'   "$PACKAGE_ROOT"
printf 'export INSTALL_ROOT=%q\n'   "$INSTALL_ROOT"
printf 'export INSTALL_DIR=%q\n'    "$INSTALL_DIR"
printf 'export BIN_DIR=%q\n'        "$BIN_DIR"
printf 'export CURL_OPTS=%q\n'      "$CURL_OPTS"
printf 'export MAKE_OPTS=%q\n'      "$MAKE_OPTS"
printf 'export CFG_OPTS=%q\n'       "$CFG_OPTS"
printf 'export CFG_OPTS_LT=%q\n'    "$CFG_OPTS_LT"
printf 'export CFG_OPTS_RT=%q\n'    "$CFG_OPTS_RT"
echo
>>>>>>> upstream/master


#
# HELPERS
#

bold() { # [message] : Display bold message
    echo "$bold$1$off"
}

fail() { # [message] : Display bold error message and exit immediately
    bold "ERROR: $@"
    exit 1
}

clean() { # [package-version] : Clean up generated files in directory of packages
    local i sdir

    for i in $sub_dirs; do
        [[ -n "$1" && ! "$i" = "$1" ]] && continue
        sdir="${i%%-*}"
        ( cd "$i" && "$make_bin" clean && rm -rf "$tarballs_dir/DONE-$sdir" >/dev/null )
    done
}

clean_all() { # [package-version] : Remove all created directories in the working directory
    [[ -d "$tarballs_dir" && -f "$tarballs_dir/DONE-PKG" ]] && rm -f "$tarballs_dir/DONE-PKG" >/dev/null

    local i sdir

    for i in $sub_dirs; do
        [[ -n "$1" && ! "$i" = "$1" ]] && continue
        sdir="${i%%-*}"
        [[ ! -d "$i" ]] || rm -rf "$i" >/dev/null && rm -rf "$tarballs_dir/DONE-$sdir" >/dev/null
    done
}

check_deps() { # Check command and package dependency
    [[ -d "$build_root" ]] || fail "$build_root doesn't exist, it needs to be created first!"

    local dep pkg cmd have_dep='' installer=''

    for dep in "${build_cmd_deps[@]}"; do
        pkg="${dep%%:*}"
        cmd="${dep##*:}"

        if which "$cmd" &>/dev/null; then :; else
            echo "You don't have the '$cmd' command available, you likely need to:"
            bold "    sudo apt-get install $pkg"
            exit 1
        fi
    done

<<<<<<< HEAD
    if which dpkg &>/dev/null; then
        have_dep='dpkg -l'
        installer='apt-get install'
    elif which pacman &>/dev/null; then
=======
    local have_dep=''
    local installer=''

    if which dpkg >/dev/null; then
        have_dep='dpkg -l'
        installer='apt-get install'
    elif which pacman >/dev/null; then
>>>>>>> upstream/master
        have_dep='pacman -Q'
        installer='pacman -S'
    fi

<<<<<<< HEAD
    if [[ -n "$installer" ]]; then
        for dep in "${build_pkg_deps[@]}"; do
            if ! $have_dep "$dep" &>/dev/null; then
=======
    if test -n "$installer"; then
        for dep in "${BUILD_PKG_DEPS[@]}"; do
            if ! $have_dep "$dep" >/dev/null; then
>>>>>>> upstream/master
                echo "You don't have the '$dep' package installed, you likely need to:"
                bold "    sudo $installer $dep"
                exit 1
            fi
        done
    fi
}

<<<<<<< HEAD
prep() { # Check dependency and create basic directories
    [[ -f "$build_dir/bin/rtorrent" ]] && fail "Current '$rt_ps_ch_version' version is already built in '$build_dir', it has to be removed manually before a new compilation."

    check_deps
    mkdir -p "$build_root"/{bin,lib}
    mkdir -p "$tarballs_dir"
}

check_hash() { # [package-version.tar.gz] : md5 hashcheck downloaded packages
    [[ "$check_hash_packages" = true ]] || return 0

    local srchash pkg hash
=======
symlink_binary() {
    binary="$INSTALL_DIR/bin/rtorrent"
    flavour="$1"
    test -z "$flavour" || ln -f "$binary" "$binary$flavour"

    mkdir -p "$BIN_DIR"
    ln -nfs "$binary$flavour" "$BIN_DIR"/rtorrent-$RT_VERSION-$RT_PS_REVISION
    test -e "$BIN_DIR"/rtorrent || ln -nfs rtorrent-$RT_VERSION-$RT_PS_REVISION "$BIN_DIR"/rtorrent
}
>>>>>>> upstream/master

    for srchash in "${src_pkg_hashes[@]}"; do
        pkg="${srchash%%:*}"
        hash="${srchash##*:}"

<<<<<<< HEAD
        if [ "$1" == "$pkg" ]; then
            echo "$hash  $tarballs_dir/$pkg" | md5sum -c --status &>/dev/null && break
            rm -f "$tarballs_dir/$pkg" && fail "Checksum failed for $pkg"
        fi
    done
}

download() { # [package-version] : Download and unpack sources
    [[ -d "$tarballs_dir" && -f "$tarballs_dir/DONE-PKG" ]] && rm -f "$tarballs_dir/DONE-PKG" >/dev/null

    local url url_base tarball_dir
=======
#
# RULES
#
prep() {
    # Create directories
    check_deps

    # Properly bump version, even if upstream doesn't
    RT_RELEASE_VERSION="$RT_VERSION"
    INSTALL_RELEASE_DIR="${INSTALL_DIR}"
    if $BUILD_GIT; then
        RT_VERSION="${RT_RELEASE_VERSION/%.$RT_MINOR/.$GIT_MINOR}"
        INSTALL_DIR="${INSTALL_RELEASE_DIR//$RT_RELEASE_VERSION/$RT_VERSION}"

        mkdir -p $INSTALL_DIR/{bin,include,lib,man,share}
    fi

    mkdir -p $INSTALL_RELEASE_DIR/{bin,include,lib,man,share}
    mkdir -p tarballs
}

download() { ## Download and unpack sources
    if test ! -d .git -a ! -d patches; then
        git clone $SELF_URL tarballs/self
        rm tarballs/self/build.sh
        mv tarballs/self/* tarballs/self/.git .
    fi
>>>>>>> upstream/master

    if [ -n "$xmlrpc_svn_url" ]; then
        # getting xmlrpc-c from SVN
        [[ -d "xmlrpc-c-$xmlrpc_tree-$xmlrpc_rev" ]] || [[ -n "$1" && "xmlrpc-c-$xmlrpc_tree-$xmlrpc_rev" = "$1" || -z "${1+x}" ]] \
            && ( echo "Getting xmlrpc-c r$xmlrpc_rev" && svn -q checkout "$xmlrpc_svn_url" "xmlrpc-c-$xmlrpc_tree-$xmlrpc_rev" \
                 || fail "xmlrpc-c-$xmlrpc_tree-$xmlrpc_rev could not be checked out from SVN.")
    fi
<<<<<<< HEAD

    for url in "${tarballs[@]}"; do
        url_base="${url##*/}"

        # skip downloading here xmlrpc-c for svn, rtorrent and libtorrent if git version should be used
        [ -z "${url_base##*xmlrpc*}" ] && [ -n "$xmlrpc_svn_url" ] && continue
        [ -z "${url_base##*rtorrent*}" ] && [ "$rt_version" = "$rt_major.$git_minor" ] && continue
        [ -z "${url_base##*libtorrent*}" ] && [ "$rt_version" = "$rt_major.$git_minor" ] && continue

        tarball_dir="${url_base%.tar.gz}"
        tarball_dir="${tarball_dir%-src.tgz}"

        [[ -n "$1" && ! "$tarball_dir" = "$1" ]] && continue
        [[ -f "$tarballs_dir/${url_base}" ]] || ( echo "Getting $url_base" && command cd "$tarballs_dir" && curl -O $curl_opts "$url" )
        [[ -d "$tarball_dir" ]] || ( check_hash "$url_base" && echo "Unpacking $url_base" && tar xfz "$tarballs_dir/$url_base" || fail "Tarball $url_base could not be unpacked." )
    done

    if [ "$rt_version" = "$rt_major.$git_minor" ]; then
        # getting rtorrent and libtorrent from GitHub
        if [ -z "${1+x}" ]; then
            download_git 'rakshasa' 'libtorrent' "$git_lt"
            download_git 'rakshasa' 'rtorrent' "$git_rt"
        elif [ "rtorrent-$git_rt" = "$1" ]; then
            download_git 'rakshasa' 'rtorrent' "$git_rt"
        elif [ "libtorrent-$git_lt" = "$1" ]; then
            download_git 'rakshasa' 'libtorrent' "$git_lt"
        fi
    fi

    touch "$tarballs_dir/DONE-PKG"
}

download_git() { # owner project commit|branch : Download from GitHub
    local owner="$1" repo="$2" repo_ver="$3" url display_ver

    url="https://github.com/$owner/$repo/archive/$repo_ver.tar.gz"
    [ "$repo" == 'rtorrent' ] && display_ver="$rt_version" || display_ver="$lt_version"

    [[ -f "$tarballs_dir/$repo-$repo_ver.tar.gz" ]] || ( echo "Getting $repo-$repo_ver.tar.gz" && command cd "$tarballs_dir" && curl $curl_opts -o "$repo-$repo_ver.tar.gz" "$url" )
    rm -rf "$repo-$repo_ver"* >/dev/null && ( check_hash "$repo-$repo_ver.tar.gz" && echo "Unpacking $repo-$repo_ver.tar.gz" && tar xfz "$tarballs_dir/$repo-$repo_ver.tar.gz" || fail "Tarball $repo-$repo_ver.tar.gz could not be unpacked.")
    [[ ! -d "$repo-$display_ver" ]] && mv "$repo-$repo_ver"* "$repo-$display_ver" || fail "'$repo-$display_ver' dir is already exist so temp dir '$repo-$repo_ver'* can't be renamed."
=======
    for url in "${TARBALLS[@]}"; do
        url_base=${url##*/}
        tarball_dir=${url_base%.tar.gz}
        tarball_dir=${tarball_dir%-src.tgz}
        test -f tarballs/${url_base} || ( echo "Getting $url_base" && command cd tarballs && curl -O $CURL_OPTS $url )
        test -d $tarball_dir || ( echo "Unpacking ${url_base}" && tar xfz tarballs/${url_base} )
        test -d $tarball_dir || fail "Tarball ${url_base} could not be unpacked"
    done

    touch tarballs/DONE
>>>>>>> upstream/master
}

build_cares() { # Build direct dependency: c-ares
    [[ -e "$tarballs_dir/DONE-PKG" ]] || fail "You need to '$0 download' first!"
    [[ -d "$tarballs_dir" && -f "$tarballs_dir/DONE-cares" ]] && rm -f "$tarballs_dir/DONE-cares" >/dev/null

    bold '~~~~~~~~~~~~~~~~~~~~~~~~   Building c-ares   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
    ( set +x ; cd "c-ares-$cares_version" \
        && ./configure --prefix="$build_dir" \
        && $make_bin $make_opts \
        && $make_bin install \
        || fail "during building 'c-ares'!" )

    touch "$tarballs_dir/DONE-cares"
}

<<<<<<< HEAD
build_curl() { # Build direct dependency: curl
    [[ -e "$tarballs_dir/DONE-PKG" && -f "$tarballs_dir/DONE-cares" ]] || fail "You need to build 'c-ares' first!"
    [[ -d "$tarballs_dir" && -f "$tarballs_dir/DONE-curl" ]] && rm -f "$tarballs_dir/DONE-curl" >/dev/null
    [[ -d "$tarballs_dir" && -f "$tarballs_dir/DONE-curl-chrpath" ]] && rm -f "$tarballs_dir/DONE-curl-chrpath" >/dev/null

    bold '~~~~~~~~~~~~~~~~~~~~~~~~   Building curl   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
    ( set +x ; cd "curl-$curl_version" \
        && ./configure --prefix="$build_dir" --enable-ares="$build_dir" --with-ssl --without-nss --without-libssh2 --without-librtmp --without-libidn2 \
             --disable-ntlm-wb --disable-sspi --disable-threaded-resolver --disable-libcurl-option --disable-manual --disable-gopher --disable-smtp --disable-file \
             --disable-smb --disable-imap --disable-pop3 --disable-tftp --disable-telnet --disable-dict --disable-rtsp --disable-ldap --disable-ftp \
        && $make_bin $make_opts \
        && $make_bin install \
        || fail "during building 'curl'!" )

    touch "$tarballs_dir/DONE-curl"
}

build_xmlrpc() { # Build direct dependency: xmlrpc-c
    [[ -e "$tarballs_dir/DONE-PKG" ]] || fail "You need to '$0 download' first!"
    [[ -d "$tarballs_dir" && -f "$tarballs_dir/DONE-xmlrpc" ]] && rm -f "$tarballs_dir/DONE-xmlrpc" >/dev/null

    bold '~~~~~~~~~~~~~~~~~~~~~~~~   Building xmlrpc-c   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
    ( set +x ; cd "xmlrpc-c-$xmlrpc_tree-$xmlrpc_rev" \
        && ./configure --prefix="$build_dir" --with-libwww-ssl --disable-wininet-client --disable-curl-client --disable-libwww-client --disable-abyss-server \
             --disable-cgi-server --disable-cplusplus \
        && $make_bin $make_opts \
        && $make_bin install \
        || fail "during building 'xmlrpc-c'!" )

    touch "$tarballs_dir/DONE-xmlrpc"
}

build_deps() { # Build direct dependencies: c-ares, curl, xmlrpc-c
    build_cares
    build_curl
    build_xmlrpc
}

build_lt() { # Build libTorrent
    [[ -e "$tarballs_dir/DONE-PKG" ]] || fail "You need to '$0 download' first!"
    [[ -d "$tarballs_dir" && -f "$tarballs_dir/DONE-libtorrent" ]] && rm -f "$tarballs_dir/DONE-libtorrent" >/dev/null

    bold '~~~~~~~~~~~~~~~~~~~~~~~~   Building libTorrent   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
    ( set +x ; cd "libtorrent-$lt_version" \
        && ./autogen.sh \
        && ./configure --prefix="$build_dir" $cfg_opts $cfg_opts_lt \
        && $make_bin $make_opts \
        && $make_bin install \
        || fail "during building 'libtorrent'!" )

    touch "$tarballs_dir/DONE-libtorrent"
}

build_rt() { # Build rTorrent
    [[ -e "$tarballs_dir/DONE-PKG" && -f "$tarballs_dir/DONE-cares" && -f "$tarballs_dir/DONE-curl" && -f "$tarballs_dir/DONE-xmlrpc" && -f "$tarballs_dir/DONE-libtorrent" ]] || fail "You need to build 'c-ares', 'curl', 'xmlrpc-c', 'libtorrent' first!"
    [[ -d "$tarballs_dir" && -f "$tarballs_dir/DONE-rtorrent" ]] && rm -f "$tarballs_dir/DONE-rtorrent" >/dev/null
    [[ -d "$tarballs_dir" && -f "$tarballs_dir/DONE-rtorrent-chrpath" ]] && rm -f "$tarballs_dir/DONE-rtorrent-chrpath" >/dev/null

    bold '~~~~~~~~~~~~~~~~~~~~~~~~   Building rTorrent   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
    ( set +x ; cd "rtorrent-$rt_version" \
        && ./autogen.sh \
        && ./configure --prefix="$build_dir" $cfg_opts $cfg_opts_rt --with-ncursesw --with-xmlrpc-c="$build_dir/bin/xmlrpc-c-config" \
        && $make_bin $make_opts \
        && $make_bin install \
        || fail "during building 'rtorrent'!" )

    touch "$tarballs_dir/DONE-rtorrent"

    change_rpath
}

build_lt_rt() { # Build libTorrent and rTorrent
    build_lt
    build_rt
}

change_rpath() { # Change rpath (to remove a possible absolute path) in libcurl.so and rtorrent binaries
    if [[ -f "$tarballs_dir/DONE-curl" && ! -f "$tarballs_dir/DONE-curl-chrpath" && -f "$build_dir/lib/libcurl.so" ]]; then
        bold '~~~~~~~~~~~~~~~~~~~~~~~~   Changing RPATH in libcurl.so   ~~~~~~~~~~~~~~~~~~~~~~~~~~'

        chrpath -r "\$ORIGIN/../lib:\$ORIGIN/../lib/$rt_ps_ch_dirname/lib" "$build_dir/lib/libcurl.so" \
            && touch "$tarballs_dir/DONE-curl-chrpath" || fail "changing RPATH in 'libcurl.so'!"
    fi

    if [[ -f "$tarballs_dir/DONE-rtorrent" && ! -f "$tarballs_dir/DONE-rtorrent-chrpath" && -f "$build_dir/bin/rtorrent" ]]; then
        bold '~~~~~~~~~~~~~~~~~~~~~~~~   Changing RPATH in rtorrent   ~~~~~~~~~~~~~~~~~~~~~~~~~~'

        chrpath -r "\$ORIGIN/../lib:\$ORIGIN/../lib/$rt_ps_ch_dirname/lib" "$build_dir/bin/rtorrent" \
            && touch "$tarballs_dir/DONE-rtorrent-chrpath" || fail "changing RPATH in 'rtorrent'!"
    fi

    chmod -R go-w "$build_dir"
    chmod 644 "$build_dir/lib"/*.so*
}

patch_lt_vanilla() { # Patch vanilla libTorrent
    [[ -d "$src_dir/patches" && "$patch_build" = yes ]] || return 0
    [[ -e "$tarballs_dir/DONE-PKG" && -d "libtorrent-$lt_version" ]] || fail "You need to '$0 download' first!"

    bold '~~~~~~~~~~~~~~~~~~~~~~~~   Patching vanilla libTorrent   ~~~~~~~~~~~~~~~~~~~~~~~~~~'

    local vanilla
    pushd "libtorrent-$lt_version"

    for vanilla in "$src_dir/patches"/vanilla_lt_{*"${lt_version%-svn}"*,all}_*.patch; do
        [[ ! -e "$vanilla" ]] || { bold "$(basename "$vanilla")"; patch -uNp1 -i "$vanilla"; }
    done

    popd
}

patch_rt_vanilla() { # Patch vanilla rTorrent
    [[ -d "$src_dir/patches" && "$patch_build" = yes ]] || return 0
    [[ -e "$tarballs_dir/DONE-PKG" && -d "rtorrent-$rt_version" ]] || fail "You need to '$0 download' first!"

    bold '~~~~~~~~~~~~~~~~~~~~~~~~   Patching vanilla rTorrent   ~~~~~~~~~~~~~~~~~~~~~~~~~~'

    local vanilla
    pushd "rtorrent-$rt_version"

    for vanilla in "$src_dir/patches"/vanilla_rt_{*"${rt_version%-svn}"*,all}_*.patch; do
        [[ ! -e "$vanilla" ]] || { bold "$(basename "$vanilla")"; patch -uNp1 -i "$vanilla"; }
    done

    popd
}

patch_lt() { # Patch libTorrent
    [[ -d "$src_dir/patches" && "$patch_build" = yes ]] || return 0
    [[ -e "$tarballs_dir/DONE-PKG" && -d "libtorrent-$lt_version" ]] || fail "You need to '$0 download' first!"

    patch_lt_vanilla

    bold '~~~~~~~~~~~~~~~~~~~~~~~~   Patching libTorrent   ~~~~~~~~~~~~~~~~~~~~~~~~~~'

    local corepatch backport
    pushd "libtorrent-$lt_version"
=======
build_deps() {
    # Build direct dependencies
    test -e $SRC_DIR/tarballs/DONE || fail "You need to '$0 download' first!"

    ( cd c-ares-$CARES_VERSION && ./configure \
        && $MAKE $MAKE_OPTS && $MAKE DESTDIR=$INSTALL_DIR prefix= install \
        || fail "Cannot build or install 'c-ares'!" )
    $SED_I s:/usr/local:$INSTALL_DIR: $INSTALL_DIR/lib/pkgconfig/*.pc $INSTALL_DIR/lib/*.la

    ( cd curl-$CURL_VERSION && ./configure --enable-ares \
        && $MAKE $MAKE_OPTS && $MAKE DESTDIR=$INSTALL_DIR prefix= install \
        || fail "Cannot build or install 'curl'!" )
    $SED_I s:/usr/local:$INSTALL_DIR: $INSTALL_DIR/lib/pkgconfig/*.pc $INSTALL_DIR/lib/*.la

    ( cd xmlrpc-c-advanced-$XMLRPC_REV \
        && $SED_I s:PGROGRAMDESTDIR:PROGRAMDESTDIR: common.mk \
        && ./configure --prefix=$INSTALL_DIR --with-libwww-ssl \
            --disable-wininet-client --disable-curl-client --disable-libwww-client --disable-abyss-server --disable-cgi-server \
        && $MAKE $MAKE_OPTS && $MAKE DESTDIR=$INSTALL_DIR prefix= install \
        || fail "Cannot build or install 'xmlrpc-c'!" )
    $SED_I s:/usr/local:$INSTALL_DIR: \
        $INSTALL_DIR/bin/xmlrpc-c-config

    $(command which libtool || echo true) --finish $INSTALL_DIR/lib
    touch $INSTALL_DIR/lib/DEPS-DONE
}

core_unpack() { # Unpack original LT/RT source
    test -f "$INSTALL_DIR/lib/DEPS-DONE" || fail "You need to '$0 deps' first!"

    tar xfz tarballs/libtorrent-$LT_VERSION.tar.gz
    tar xfz tarballs/rtorrent-$RT_VERSION.tar.gz

    # Patch libtorrent (vanilla)
    pushd libtorrent-$LT_VERSION
    for corepatch in "${LT_BASE_PATCHES[@]}"; do
        test ! -e "$corepatch" || { bold "$(basename $corepatch)"; patch -uNp1 -i "$corepatch"; }
    done
    popd

    # Patch rTorrent (vanilla)
    pushd rtorrent-$RT_VERSION
    for corepatch in "${RT_BASE_PATCHES[@]}"; do
        test ! -e "$corepatch" || { bold "$(basename $corepatch)"; patch -uNp1 -i "$corepatch"; }
    done
    popd
}

build() { ## Build and install all components
    test -f "$INSTALL_DIR/lib/DEPS-DONE" || fail "You need to '$0 deps' first!"

    ( set +x ; $USE_CXXFLAGS || unset CXXFLAGS; cd libtorrent-$LT_VERSION && automagic && \
        ./configure $CFG_OPTS $CFG_OPTS_LT && $MAKE clean && $MAKE $MAKE_OPTS && $MAKE prefix=$INSTALL_DIR install )
    $SED_I s:/usr/local:$INSTALL_DIR: $INSTALL_DIR/lib/pkgconfig/*.pc $INSTALL_DIR/lib/*.la
    ( set +x ; $USE_CXXFLAGS || unset CXXFLAGS; cd rtorrent-$RT_VERSION && automagic && \
        ./configure $CFG_OPTS $CFG_OPTS_RT --with-xmlrpc-c=$INSTALL_DIR/bin/xmlrpc-c-config && \
        $MAKE clean && $MAKE $MAKE_OPTS && $MAKE prefix=$INSTALL_DIR install )
}

build_git() { ## a/k/a ‹git› – Build and install libtorrent and rtorrent from git checkouts
    # Start script should contain:
    #
    #   BIN="$HOME/src/rakshasa-rtorrent/src/"; LD_PRELOAD=$HOME/lib/rtorrent/0.9.7-PS-1.0-dev/lib/libtorrent.so.19 \
    #   ${BIN}rtorrent -n -o import=$PWD/rtorrent.rc

    local lt_src="../rakshasa-libtorrent"; test -d "$lt_src" || lt_src="../libtorrent"
    local rt_src="../rakshasa-rtorrent"; test -d "$rt_src" || rt_src="../rtorrent"

    test -f "$INSTALL_DIR/lib/DEPS-DONE" || fail "You need to '$0 deps' first!"

    # TODO: ++ LIBTORRENT_CURRENT=19
    $SED_I 's/^AC_INIT(libtorrent, '${LT_VERSION}'/AC_INIT(libtorrent, '${LT_VERSION%.*}.$GIT_MINOR'/' "$lt_src/configure.ac"
    $SED_I 's/^AC_INIT(rtorrent, '$RT_RELEASE_VERSION'/AC_INIT(rtorrent, '$RT_VERSION'/' "$rt_src/configure.ac"

    echo; echo "*** Entering $lt_src"
    ( set +x ; $USE_CXXFLAGS || unset CXXFLAGS; cd "$lt_src" && automagic && \
        ./configure $CFG_OPTS $CFG_OPTS_LT && $MAKE clean && $MAKE $MAKE_OPTS && $MAKE prefix=$INSTALL_DIR install )
    $SED_I s:/usr/local:$INSTALL_DIR: $INSTALL_DIR/lib/pkgconfig/*.pc $INSTALL_DIR/lib/*.la

    echo; echo "*** Entering $rt_src"
    ( set +x ; $USE_CXXFLAGS || unset CXXFLAGS; cd "$rt_src" && automagic && \
        ./configure $CFG_OPTS $CFG_OPTS_RT --with-xmlrpc-c=$INSTALL_RELEASE_DIR/bin/xmlrpc-c-config && \
        $MAKE clean && $MAKE $MAKE_OPTS && $MAKE prefix=$INSTALL_DIR install )
}

extend() { ## Rebuild and install libtorrent and rTorrent with patches applied
    test -f "$INSTALL_DIR/lib/DEPS-DONE" || fail "You need to '$0 deps' first!"
    core_unpack

    # Version handling
    RT_HEX_VERSION=$(printf "0x%02X%02X%02X" ${RT_VERSION//./ })
    $SED_I "s:\\(AC_DEFINE(HAVE_CONFIG_H.*\\):\1  AC_DEFINE(RT_HEX_VERSION, $RT_HEX_VERSION, for CPP if checks):" rtorrent-$RT_VERSION/configure.ac
    grep "AC_DEFINE.*API_VERSION" rtorrent-$RT_VERSION/configure.ac >/dev/null || \
        $SED_I "s:\\(AC_DEFINE(HAVE_CONFIG_H.*\\):\1  AC_DEFINE(API_VERSION, 0, api version):" rtorrent-$RT_VERSION/configure.ac
>>>>>>> upstream/master

    for corepatch in "$src_dir/patches"/lt-ps_{*"${lt_version%-svn}"*,all}_*.patch; do
        [[ ! -e "$corepatch" ]] || { bold "$(basename "$corepatch")"; patch -uNp1 -i "$corepatch"; }
    done

<<<<<<< HEAD
    for backport in "$src_dir/patches"/{backport,misc}_lt_{*"${lt_version%-svn}"*,all}_*.patch; do
        [[ ! -e "$backport" ]] || { bold "$(basename "$backport")"; patch -uNp1 -i "$backport"; }
=======
    for corepatch in $SRC_DIR/patches/lt-ps-*_{${LT_VERSION},all}.patch "${LT_PATCHES[@]}"; do
        test ! -e "$corepatch" || { bold "$(basename $corepatch)"; patch -uNp1 -i "$corepatch"; }
    done

    for backport in $SRC_DIR/patches/backport*_{${LT_VERSION},all}_*.patch; do
        test ! -e "$backport" || { bold "$(basename $backport)"; patch -uNp1 -i "$backport"; }
>>>>>>> upstream/master
    done

    popd
}

patch_rt() { # Patch rTorrent
    [[ -d "$src_dir/patches" && "$patch_build" = yes ]] || return 0
    [[ -e "$tarballs_dir/DONE-PKG" && -d "rtorrent-$rt_version" ]] || fail "You need to '$0 download' first!"

    patch_rt_vanilla

<<<<<<< HEAD
    bold '~~~~~~~~~~~~~~~~~~~~~~~~   Patching rTorrent   ~~~~~~~~~~~~~~~~~~~~~~~~~~'

    local corepatch backport pyropatch i uipyropatch rt_hex_version ch_separator
    pushd "rtorrent-$rt_version"

    for corepatch in "$src_dir/patches"/ps-*_{*"${rt_version%-svn}"*,all}.patch; do
        [[ ! -e "$corepatch" ]] || { bold "$(basename "$corepatch")"; patch -uNp1 -i "$corepatch"; }
    done

    for backport in "$src_dir/patches"/{backport,misc}_rt_{*"${rt_version%-svn}"*,all}_*.patch; do
        [[ ! -e "$backport" ]] || { bold "$(basename "$backport")"; patch -uNp1 -i "$backport"; }
=======
    # Patch rTorrent
    pushd rtorrent-$RT_VERSION

    for corepatch in $SRC_DIR/patches/ps-*_{${RT_VERSION},all}.patch "${RT_PATCHES[@]}"; do
        test ! -e "$corepatch" || { bold "$(basename $corepatch)"; patch -uNp1 -i "$corepatch"; }
    done

    for backport in $SRC_DIR/patches/backport*_${RT_VERSION}_*.patch; do
        test ! -e "$backport" || { bold "$(basename $backport)"; patch -uNp1 -i "$backport"; }
>>>>>>> upstream/master
    done

    ${nopyrop:-false} || for pyropatch in "$src_dir/patches"/pyroscope_{*"${rt_version%-svn}"*,all}.patch; do
        [[ ! -e "$pyropatch" ]] || { bold "$(basename "$pyropatch")"; patch -uNp1 -i "$pyropatch"; }
    done

<<<<<<< HEAD
    ${nopyrop:-false} || for i in "$src_dir/patches"/*.{cc,h}; do
        ln -nfs "$i" src
    done

    ${nopyrop:-false} || for uipyropatch in "$src_dir/patches"/ui_pyroscope_{*"${rt_version%-svn}"*,all}.patch; do
        [[ ! -e "$uipyropatch" ]] || { bold "$(basename "$uipyropatch")"; patch -uNp1 -i "$uipyropatch"; }
    done

    # Version handling
    rt_hex_version=$(printf "0x%02X%02X%02X" ${rt_version//./ })
    ${nopyrop:-false} || $sed_i "s:\\(AC_DEFINE(HAVE_CONFIG_H.*\\):\1  AC_DEFINE(RT_HEX_VERSION, $rt_hex_version, for CPP if checks):" configure.ac

    [[ "$optimize_build" = yes ]] && ch_separator="+" || ch_separator="-"
    ${nopyrop:-false} || $sed_i "s%rTorrent \\\" VERSION \\\"/\\\"%$rt_ps_ch_title $rt_ps_ch_version $rt_version/$lt_version $ch_separator \\\"%" src/ui/download_list.cc
    ${nopyrop:-false} || $sed_i "s%std::string(torrent::version()) + \\\" - \\\" +%%" src/ui/download_list.cc

=======
    bold "ui_pyroscope.patch"
    patch -uNp1 -i "${SRC_DIR}/patches/ui_pyroscope.patch"

    $SED_I 's/rTorrent \" VERSION/rTorrent'"$VERSION_EXTRAS"' " VERSION/' src/ui/download_list.cc
>>>>>>> upstream/master
    popd
}

patch_lt_rt_vanilla() { # Patch vanilla libTorrent and rTorrent
    patch_lt_vanilla
    patch_rt_vanilla
}

<<<<<<< HEAD
patch_lt_rt() { # Patch libTorrent and rTorrent
    patch_lt
    patch_rt
}

clean_up() { # Remove unnecessary files from compilation dir
    rm -rf "$build_dir/"{lib/*.a,lib/*.la,lib/pkgconfig,share/man,man,share,include,bin/curl,bin/*-config}
}

add_version_info() { # Display version info
    [[ -d "$build_dir" ]] || fail "Could not locate dir '$build_dir'"

    cat >"$build_dir/$ver_info_filename" <<.
rt_ps_ch_version='$rt_ps_ch_version${vanilla_postfix}'
rt_ps_ch_rt_version='$rt_version'
rt_ps_ch_lt_version='$lt_version'
rt_ps_ch_revision='$(date +'%Y%m%d')'
rt_ps_ch_cares_version='$cares_version'
rt_ps_ch_curl_version='$curl_version'
rt_ps_ch_xmlrpc_tree='$xmlrpc_tree'
rt_ps_ch_xmlrpc_rev='$xmlrpc_rev'
optimized_build='$optimize_build'
.

    # Add docs as well if it's not the vanilla build
    if [ -z "${vanilla_postfix+x}" ]; then
        [[ -d "$src_dir/docs" ]] && \cp -rf "$src_dir/docs" "$build_dir/" || fail "Could not copy 'docs' dir into '$build_dir'"
        \cp -f "$src_dir"/{README.rst,LICENSE,CHANGELOG.md} "$build_dir/" || fail "Could not copy doc files into '$build_dir'"
    fi

    chmod -R go-w "$build_dir/"
}

symlink_binary_home() { # Symlink binary in HOME
    [[ ! -f "$build_dir/bin/rtorrent" ]] && fail "Compilation hasn't been finished, try it again."

    cd "$build_root/lib"
    ln -nfs "$rt_ps_ch_dirname-$rt_ps_ch_version-$rt_version" "$rt_ps_ch_dirname"
    cd "$build_root/bin"
    ln -nfs "../lib/$rt_ps_ch_dirname/bin/rtorrent" "rtorrent${vanilla_postfix}"
    cd "$src_dir"
}

symlink_binary_inst() { # Symlink binary after it's installed into $root_pkg_dir dir
    [[ ! -f "$pkg_inst_dir/bin/rtorrent" ]] && fail "Installation hasn't been finished, try it again."
    [[ -f "$root_sys_dir/bin/rtorrent" && ! -L "$root_sys_dir/bin/rtorrent" ]] && fail "Could not create symlink 'rtorrent' in '$root_sys_dir/bin/'"
    [[ -d "$root_sys_dir/lib/$rt_ps_ch_dirname" || -f "$root_sys_dir/lib/$rt_ps_ch_dirname" ]] && [[ ! -L "$root_sys_dir/lib/$rt_ps_ch_dirname" ]] && fail "Could not create symlink '$rt_ps_ch_dirname' in '$root_sys_dir/lib/'"
    [[ -d "$root_symlink_dir" || -f "$root_symlink_dir" ]] && [[ ! -L "$root_symlink_dir" ]] && fail "Could not create symlink '$rt_ps_ch_dirname' in '$root_pkg_dir/'"

    cd "$root_pkg_dir"
    ln -nfs "$rt_ps_ch_dirname-$rt_ps_ch_version-$rt_version" "$rt_ps_ch_dirname"
    ln -nfs "$root_symlink_dir" "$root_sys_dir/lib/$rt_ps_ch_dirname"
    cd "$root_sys_dir/bin"
    ln -nfs "../lib/$rt_ps_ch_dirname/bin/rtorrent" 'rtorrent'
    cd "$src_dir"
}

check() { # root_dir : Print some diagnostic success indicators
    bold 'Checking links:'
    echo

    if [ "$1" == "$build_root" ]; then
        echo "$1/bin/rtorrent${vanilla_postfix} ->" $(readlink "$1/bin/rtorrent${vanilla_postfix}") | sed -e "s:$HOME/:~/:g"
        echo "$1/lib/$rt_ps_ch_dirname ->" $(readlink "$1/lib/$rt_ps_ch_dirname") | sed -e "s:$HOME/:~/:g"
    else
        echo "$1/bin/rtorrent ->" $(readlink "$1/bin/rtorrent")
        echo "$1/lib/$rt_ps_ch_dirname ->" $(readlink "$1/lib/$rt_ps_ch_dirname")
        echo "$root_symlink_dir ->" $(readlink "$root_symlink_dir")
    fi
=======
clean() { ## Clean up generated files
    for i in $SUBDIRS; do
        ( cd $i && $MAKE clean )
    done
}

clean_all() { ## Remove all downloads and created files
    rm tarballs/*{.tar.gz,.tgz} tarballs/DONE >/dev/null 2>&1 || :
    for i in $SUBDIRS; do
        test ! -d $i || rm -rf $i >/dev/null
    done
}

check() { ## Print some diagnostic success indicators
    for i in "$BIN_DIR"/rtorrent{,-*}; do
        echo $i "->" $(readlink $i) | sed -e "s:$HOME:~:g"
    done
>>>>>>> upstream/master

    # This first selects the rpath dependencies, and then filters out libs found in the install dirs.
    # If anything is left, we have an external dependency that sneaked in.
    echo
<<<<<<< HEAD
    echo -n 'Check that static linking worked: '

    local libs=$(ldd "$1/bin/rtorrent${vanilla_postfix}" | egrep "lib(cares|curl|xmlrpc|torrent)")	#"

    if [[ "$(echo "$libs" | egrep -v "$1/bin" | wc -l)" -eq 0 ]]; then
        echo OK; echo
    else
        echo FAIL; echo; echo 'Suspicious library paths are:'
        echo "$libs" | egrep -v "$1/bin" || :
        echo
    fi

    echo 'Dependency library paths:'
    echo "$libs" | sed -e "s:$1/bin/::g"
}

install() { # Install (copy) to $pkg_inst_dir
    [[ ! -f "$build_dir/$ver_info_filename" ]] && fail "Compilation hasn't been finished, try it again."
    [[ -d "$pkg_inst_dir" && -f "$pkg_inst_dir/bin/rtorrent" ]] && fail "Could not clean install into dir '$pkg_inst_dir', dir already exists."

    cp -r "$build_dir" "$root_pkg_dir/" || fail "Could not copy into dir '$pkg_inst_dir', have you tried with 'sudo'?"
    chmod -R a+rX "$pkg_inst_dir/"
}

pkg2tgz() { # Compress "$build_dir" into tarball
    [[ ! -f "$build_dir/$ver_info_filename" ]] && fail "Compilation hasn't been finished, try it again."

    local os_id='unknown' os_ver='unknown' os_arch="$HOSTTYPE" ch_separator='-' tgz_name

    [[ -d "$dist_dir" ]] || mkdir -p "$dist_dir"
    . "$build_dir/$ver_info_filename"

    command which lsb_release &>/dev/null && os_id="$(echo $(lsb_release -is) | tr '[:upper:]' '[:lower:]')" && os_ver="$(lsb_release -cs)"
    command which dpkg &>/dev/null && os_arch="$(dpkg --print-architecture)"
    [[ "$optimized_build" = yes ]] && ch_separator='+'
    tgz_name="${rt_ps_ch_dirname}${vanilla_postfix}_${rt_ps_ch_version}-${rt_ps_ch_rt_version}${ch_separator}${os_id}-${os_ver}_${os_arch}.tar.gz"

    cd "$build_root/lib"
    echo "${bold}Creating tarball $dist_dir/$tgz_name${off}"
    tar --owner=nobody --group=nogroup -czvf "$dist_dir/$tgz_name" "$rt_ps_ch_dirname${vanilla_postfix}-$rt_ps_ch_version-$rt_ps_ch_rt_version/"
}

package_prep() { # Helper function for pkg2* functions
    [[ -n "$debfullname" ]] || fail 'You MUST set debfullname in your environment.'
    [[ -n "$debemail" ]] || fail 'You MUST set debemail in your environment.'

    [[ -d "$pkg_inst_dir" && -f "$pkg_inst_dir/bin/rtorrent" ]] || fail "Could not package '$pkg_inst_dir', it has to be 'install'-ed first."
    [[ ! -f "$pkg_inst_dir/$ver_info_filename" ]] && fail "Could not package '$pkg_inst_dir', there's no '$ver_info_filename' file."

    . "$pkg_inst_dir/$ver_info_filename"

    [[ "$optimized_build" = yes ]] && fail "Could not package optimized build, it has to be compiled with 'optimize_build=no ./build.sh ch' first."

    [[ -d "$dist_dir" ]] || mkdir -p "$dist_dir"
}

call_fpm() { # command_line_params : Helper function for pkg2* functions
    # Prepare after install script for adding symlinks
    cat >"$tarballs_dir/after_install.sh" <<.
#!/bin/sh
set -e

if [ -d "$root_pkg_dir" ] && [ -d "$root_pkg_dir/$rt_ps_ch_dirname-$rt_ps_ch_version-$rt_version" ]; then
    cd "$root_pkg_dir" 2>/dev/null || true
    test ! -f "$rt_ps_ch_dirname" || test -L "$rt_ps_ch_dirname" && ln -nfs "$rt_ps_ch_dirname-$rt_ps_ch_version-$rt_version" "$rt_ps_ch_dirname" 2>/dev/null || true
fi

if [ -d "$root_sys_dir/lib" ] && [ -L "$root_symlink_dir" ]; then
    test ! -d "$root_sys_dir/lib/$rt_ps_ch_dirname" && test ! -f "$root_sys_dir/lib/$rt_ps_ch_dirname" || test -L "$root_sys_dir/lib/$rt_ps_ch_dirname" && ln -nfs "$root_symlink_dir" "$root_sys_dir/lib/$rt_ps_ch_dirname" 2>/dev/null || true
fi

if [ -d "$root_sys_dir/bin" ] && [ -d "$root_sys_dir/lib" ] && [ -L "$root_sys_dir/lib/$rt_ps_ch_dirname" ]; then
    cd "$root_sys_dir/bin" 2>/dev/null || true
    test ! -f 'rtorrent' || test -L 'rtorrent' && ln -nfs "../lib/$rt_ps_ch_dirname/bin/rtorrent" 'rtorrent' 2>/dev/null || true
fi

exit 0
.

    # Prepare before remove script for removing symlinks
    cat >"$tarballs_dir/before_remove.sh" <<.
#!/bin/sh
set -e

test -L "$root_sys_dir/bin/rtorrent" && rm -f "$root_sys_dir/bin/rtorrent" 2>/dev/null || true
test -L "$root_sys_dir/lib/$rt_ps_ch_dirname" && rm -f "$root_sys_dir/lib/$rt_ps_ch_dirname" 2>/dev/null || true
test -L "$root_pkg_dir/$rt_ps_ch_dirname" && rm -f "$root_pkg_dir/$rt_ps_ch_dirname" 2>/dev/null || true

exit 0
=======
    echo -n "Check that static linking worked: "
    libs=$(ldd "$BIN_DIR"/rtorrent-$RT_VERSION-$RT_PS_REVISION | egrep "lib(cares|curl|xmlrpc|torrent)")
    if test "$(echo "$libs" | egrep -v "($INSTALL_DIR|$INSTALL_RELEASE_DIR)" | wc -l)" -eq 0; then
        echo OK; echo
    else
        echo FAIL; echo; echo "Suspicious library paths are:"
        echo "$libs" | egrep -v "($INSTALL_DIR|$INSTALL_RELEASE_DIR)" || :
        echo
    fi
    echo "Dependency library paths:"
    echo "$libs" | sed -e "s:$HOME:~:g"
}

install() { ## Install to $PACKAGE_ROOT
    export INSTALL_DIR="$PACKAGE_ROOT"
    test -d "$INSTALL_DIR"/. || mkdir -p "$INSTALL_DIR"/
    rm -rf "$INSTALL_DIR"/* || :
    test "$(echo /opt/rtorrent/*)" = "/opt/rtorrent/*" || fail "Could not clean install dir '$INSTALL_DIR'"
    cat >"$INSTALL_DIR"/version-info.sh <<.
RT_PS_VERSION=$RT_VERSION-$RT_PS_REVISION
RT_PS_REVISION=$RT_PS_REVISION
RT_PS_RT_VERSION=$RT_VERSION
RT_PS_LT_VERSION=$LT_VERSION
RT_PS_CARES_VERSION=$CARES_VERSION
RT_PS_CURL_VERSION=$CURL_VERSION
RT_PS_XMLRPC_REV=$XMLRPC_REV
>>>>>>> upstream/master
.

    # Create the package
    fpm -s dir -n "${fpm_pkg_name:-$rt_ps_ch_dirname}" \
        -v "$rt_ps_ch_version-$rt_ps_ch_rt_version" --iteration "$fpm_iteration" \
        -m "\"$debfullname\" <$debemail>" \
        --license "$fpm_license" --vendor 'https://github.com/rakshasa , https://github.com/pyroscope/rtorrent-ps#rtorrent-ps' \
        --description 'Patched and extended ncurses BitTorrent client' \
        --url "https://github.com/chros73/$rt_ps_ch_dirname#$rt_ps_ch_dirname-fork-notes" \
        --after-install "$tarballs_dir/after_install.sh" \
        --before-remove "$tarballs_dir/before_remove.sh" \
        "$@" -C "$pkg_inst_dir/." --prefix "$pkg_inst_dir" '.'

    chmod a+rX .
    chmod a+r  *".$fpm_pkg_ext"

    [[ -f "$tarballs_dir/after_install.sh" ]] && rm -f "$tarballs_dir/after_install.sh" >/dev/null
    [[ -f "$tarballs_dir/before_remove.sh" ]] && rm -f "$tarballs_dir/before_remove.sh" >/dev/null
}

<<<<<<< HEAD
pkg2deb() { # Package current $pkg_inst_dir installation for APT [needs fpm]
    # You need to:
    #   aptitude install ruby ruby-dev
    #   gem install fpm
    #   which fpm || ln -s $(ls -1 /var/lib/gems/*/bin/fpm | tail -1) /usr/local/bin
=======
package_prep() # make $PACKAGE_ROOT lean and mean
{
    test -n "$DEBFULLNAME" || fail "You MUST set DEBFULLNAME in your environment"
    test -n "$DEBEMAIL" || fail "You MUST set DEBEMAIL in your environment"
>>>>>>> upstream/master

    package_prep

    fpm_pkg_ext='deb'
    fpm_iteration="$(echo $(lsb_release -is) | tr '[:upper:]' '[:lower:]')-$(lsb_release -cs)"
    fpm_license='GPL v2'
    deps=$(ldd "$pkg_inst_dir/bin/rtorrent" | cut -f2 -d'>' | cut -f2 -d' ' | egrep '^/lib/|^/usr/lib/' \
        | sed -r -e 's:^/lib.+:&\n/usr&:' | xargs -n1 dpkg 2>/dev/null -S \
        | cut -f1 -d: | sort -u | xargs -n1 echo '-d')

<<<<<<< HEAD
    ( cd "$dist_dir" && call_fpm -t deb --category 'net' $deps )

    dpkg-deb -c       "$dist_dir"/*."$fpm_pkg_ext"
    echo "~~~" $(find "$dist_dir"/*."$fpm_pkg_ext")
    dpkg-deb -I       "$dist_dir"/*."$fpm_pkg_ext"
}

pkg2pacman() { # Package current $pkg_inst_dir installation for PACMAN [needs fpm]
    # You need to install fpm from the AUR

    package_prep

    fpm_pkg_ext='tar.xz'
    fpm_iteration='arch-unknown'
    fpm_license='GPL v2'

    ( cd "$dist_dir" && call_fpm -t pacman )

    pacman -Qp --info "$dist_dir"/*."$fpm_pkg_ext"
    echo "~~~" $(find "$dist_dir"/*."$fpm_pkg_ext")
    pacman -Qp --list "$dist_dir"/*."$fpm_pkg_ext"
}

info() { # Display info
    local i

    echo >&2 "${bold}Usage: $0 (ch [git] | install [git] | pkg2deb [git] | pkg2pacman [git] | vanilla [git] | info [git])${off}"
    echo >&2 "Build $rt_ps_ch_title $rt_ps_ch_version $rt_version/$lt_version into $(sed -e s:$HOME/:~/: <<<$build_dir)"
    echo >&2
    echo >&2 'Custom environment variables:'
    echo >&2 "    curl_opts=\"${curl_opts}\" (e.g. --insecure)"
    echo >&2 "    make_opts=\"${make_opts}\""
    echo >&2 "    cfg_opts=\"${cfg_opts}\"      (e.g. --enable-debug --enable-extra-debug)"
    echo >&2 "    cfg_opts_lt=\"${cfg_opts_lt}\"   (e.g. --disable-instrumentation for MIPS, PowerPC, ARM)"  # MIPS | PowerPC | ARM users, read https://github.com/rakshasa/rtorrent/issues/156
    echo >&2 "    cfg_opts_rt=\"${cfg_opts_rt}\""
    echo >&2
    echo >&2 'Build actions:'

    grep ').\+##' "$0" | grep -v grep | sed -e 's:^:  :' -e 's:): :' -e 's:## ::' | while read i; do
        eval "echo \"   $i\""
    done

    exit 0
=======
    rm -rf "$PACKAGE_ROOT/"{lib/*.a,lib/*.la,lib/pkgconfig,share/man,man,share,include} || :
    rm -f "$PACKAGE_ROOT/bin/"{curl,*-config} || :
    chmod -R a+rX "$PACKAGE_ROOT/"

    . "$PACKAGE_ROOT"/version-info.sh
}

call_fpm() {
    fpm -s dir -n "${fpm_pkg_name:-rtorrent-ps}" \
        -v "$RT_PS_RT_VERSION" --iteration "$fpm_iteration" \
        -m "\"$DEBFULLNAME\" <$DEBEMAIL>" \
        --license "$fpm_license" --vendor "https://github.com/rakshasa" \
        --description "Patched and extended ncurses BitTorrent client" \
        --url "https://github.com/pyroscope/rtorrent-ps#rtorrent-ps" \
        "$@" -C "$PACKAGE_ROOT/." --prefix "$PACKAGE_ROOT" '.'

    chmod a+rX .
    chmod a+r  *".$fpm_pkg_ext"
}

pkg2deb() { ## Package current $PACKAGE_ROOT installation for APT [needs fpm]
    # You need to:
    #   aptitude install ruby ruby-dev
    #   gem install fpm
    #   which fpm || ln -s $(ls -1 /var/lib/gems/*/bin/fpm | tail -1) /usr/local/bin

    package_prep

    fpm_pkg_ext="deb"
    fpm_iteration="${VERSION_EXTRAS# }~"$(lsb_release -cs)
    fpm_license="GPL v2"
    deps=$(ldd "$PACKAGE_ROOT"/bin/rtorrent | cut -f2 -d'>' | cut -f2 -d' ' | egrep '^/lib/|^/usr/lib/' \
        | sed -r -e 's:^/lib.+:&\n/usr&:' | xargs -n1 dpkg 2>/dev/null -S \
        | cut -f1 -d: | sort -u | xargs -n1 echo '-d')

    ( cd "$DIST_DIR" && call_fpm -t deb --category "net" $deps )

    dpkg-deb -c       "$DIST_DIR"/*".$fpm_pkg_ext"
    echo "~~~" $(find "$DIST_DIR"/*".$fpm_pkg_ext")
    dpkg-deb -I       "$DIST_DIR"/*".$fpm_pkg_ext"
}

pkg2pacman() { ## Package current $PACKAGE_ROOT installation for PACMAN [needs fpm]
    # You need to install fpm from the AUR
    package_prep

    fpm_pkg_ext="tar.xz"
    fpm_iteration="${RT_PS_REVISION//-/.}"
    fpm_license="GPL2"

    ( cd "$DIST_DIR" && call_fpm -t pacman )

    pacman -Qp --info "$DIST_DIR"/*".$fpm_pkg_ext"
    echo "~~~" $(find "$DIST_DIR"/*".$fpm_pkg_ext")
    pacman -Qp --list "$DIST_DIR"/*".$fpm_pkg_ext"
}

build_all() { ## a/k/a ‹all› – Download and build and install all deps + vanilla + extended
    # Go through all build steps
    set_build_env
    ${NODEPS:-false} || build_deps

    core_unpack
    build
    symlink_binary -vanilla
    check

    rt_binary="$SRC_DIR/rtorrent-$RT_RELEASE_VERSION/src/rtorrent"
    test -e "$rt_binary" || fail "Something went wrong! ($rt_binary not found)"

    extend
    symlink_binary -extended
    check
>>>>>>> upstream/master
}

docker_deb() { ## Build Debian packages via Docker
    local distros distro_code DISTRO_NAME DISTRO_CODENAME DOCKER_TAG

    distro_code="${1:-${docker_distros_stable[0]}}"; test "$#" -eq 0 || shift
    case "$distro_code" in
        all)        distros=( "${docker_distros_all[@]}" ) ;;
        stable)     distros=( "${docker_distros_stable[@]}" ) ;;
        oldstable)  distros=( "${docker_distros_oldstable[@]}" ) ;;
        *)          distros=( "$distro_code" ) ;;
    esac

    for distro_code in "${distros[@]}"; do
        DISTRO_NAME=${distro_code%%:*}
        DISTRO_CODENAME=${distro_code#*:}
        DOCKER_TAG=rtps-deb-$DISTRO_CODENAME

        mkdir -p tmp-docker
        set \
            | egrep '^(git_[_a-z]+|[_A-Z]+_OPTS|[_A-Z]+_ROOT|CFG_[_A-Z]+)' \
            | sed -re 's/^/export /' >tmp-docker/docker-env
        ln -f Dockerfile.Debian tmp-docker/Dockerfile

        docker build -t $DOCKER_TAG -f tmp-docker/Dockerfile \
                     --build-arg DISTRO=$DISTRO_NAME \
                     --build-arg CODENAME=$DISTRO_CODENAME \
                     "$@" . \
            || { echo -e "\n\n*** WARNING: $distro does not build ***\n\n"; continue; }
        docker run --rm -u $(id -u):$(id -g) --userns host -v "$PWD:/pwd" $DOCKER_TAG \
                   bash -c "cp /tmp/rt-ps-dist/rtorrent-ps_*.deb /pwd"
    done
    ls -lrt *.deb
}


#
# MAIN
#
<<<<<<< HEAD
cd "$src_dir"
case "$1" in
    info)       ## Display info (taking into account the optional 2nd 'git' argument)
                info
                ;;
    ch)         ## Build all components into $(sed -e s:"$HOME"/:~/: <<<"$build_dir")
                set_compiler_flags
                display_env_vars
                clean_all
                prep
                download
                build_deps
                patch_lt_rt
                build_lt_rt
                clean_up
                add_version_info
                display_env_vars
                symlink_binary_home
                check "$build_root"
                ;;
    install)    ## Install $(sed -e s:"$HOME"/:~/: <<<"$build_dir") compilation into "$pkg_inst_dir"
                install
                symlink_binary_inst
                check "$root_sys_dir"
                ;;
    pkg2tgz)    ## Compress "$build_dir" into tarball
                pkg2tgz ;;
    pkg2deb)    ## Package "$pkg_inst_dir" installation for APT [needs fpm]
                pkg2deb ;;
    pkg2pacman) ## Package "$pkg_inst_dir" installation for PACMAN [needs fpm]
                pkg2pacman ;;
    vanilla)    ## Build all vanilla components into $(sed -e s:"$HOME"/:~/: <<<"$build_root/lib/$rt_ps_ch_dirname-vanilla-$rt_ps_ch_version-$rt_version")
                reset_vanilla_env_vars
                set_compiler_flags
                display_env_vars
                clean_all
                prep
                download
                build_deps
                patch_lt_rt_vanilla
                build_lt_rt
                clean_up
                add_version_info
                display_env_vars
                symlink_binary_home
                check "$build_root"
                ;;

    # Dev related actions
    env-vars)   set_compiler_flags; display_env_vars ;;
    clean)      clean ;;
    clean_all)  clean_all ;;
    download)   prep; download ;;
    build-ares) set_compiler_flags; display_env_vars; prep; clean_all "c-ares-$cares_version"; download "c-ares-$cares_version"; build_cares ;;
    build-curl) set_compiler_flags; display_env_vars; prep; clean_all "curl-$curl_version"; download "curl-$curl_version"; build_curl; change_rpath ;;
    build-xrpc) set_compiler_flags; display_env_vars; prep; clean_all "xmlrpc-c-$xmlrpc_tree-$xmlrpc_rev"; download "xmlrpc-c-$xmlrpc_tree-$xmlrpc_rev"; build_xmlrpc ;;
    deps)       set_compiler_flags; display_env_vars; prep; build_deps; change_rpath ;;
    patch-d-lt) nopyrop=true; display_env_vars; clean_all "libtorrent-$lt_version"; download "libtorrent-$lt_down_version"; patch_lt ;;
    patch-d-rt) nopyrop=true; display_env_vars; clean_all "rtorrent-$rt_version"; download "rtorrent-$rt_down_version"; patch_rt ;;
    patch-lt)   display_env_vars; clean_all "libtorrent-$lt_version"; download "libtorrent-$lt_down_version"; patch_lt ;;
    patch-rt)   display_env_vars; clean_all "rtorrent-$rt_version"; download "rtorrent-$rt_down_version"; patch_rt ;;
    patch-ltrt) display_env_vars; clean_all "libtorrent-$lt_version"; download "libtorrent-$lt_down_version"; clean_all "rtorrent-$rt_version"; download "rtorrent-$rt_down_version"; patch_lt_rt ;;
    build-lt)   set_compiler_flags; display_env_vars; build_lt ;;
    build-rt)   set_compiler_flags; display_env_vars; build_rt ;;
    build-ltrt) set_compiler_flags; display_env_vars; build_lt_rt ;;
    patchbuild) set_compiler_flags; display_env_vars; clean_all "libtorrent-$lt_version"; download "libtorrent-$lt_down_version"; clean_all "rtorrent-$rt_version"; download "rtorrent-$rt_down_version"; patch_lt_rt; build_lt_rt; add_version_info ;;
    chrpath)    change_rpath ;;
    clean-up)   clean_up ;;
    ver-info)   add_version_info ;;
    sm-home)    symlink_binary_home ;;
    sm-inst)    symlink_binary_inst ;;
    check-home) check "$build_root" ;;
    check-inst) check "$root_sys_dir" ;;
    *)          info ;;
esac
=======
cd "$SRC_DIR"
while test -n "$1"; do
    action="$1"; shift
    case "$action" in
        all|build_all)
                    prep; download; build_all ;;
        build)      prep; build_all ;;
        git|build_git)
                    export BUILD_GIT=true
                    prep
                    set_build_env
                    build_git
                    symlink_binary -git
                    check
                    ;;
        check)      check ;;
        clean_all)  clean_all ;;
        clean)      clean ;;
        deps)       ## Build all dependencies
                    prep; set_build_env; build_deps ;;
        deps_git)   ## Build all dependencies [GIT HEAD MODE]
                    export BUILD_GIT=true
                    prep; set_build_env; build_deps ;;
        docker_deb) docker_deb "$@"
                    break  # takes args, so must be the last action on a call
                    ;;
        download)   prep; download ;;
        env)        ## Show build environement
                    prep; set +x; set_build_env echo '"' ;;
        extend)     prep
                    set_build_env
                    extend
                    symlink_binary -extended
                    check
                    ;;
        install)    install ;;
        pkg2deb)    pkg2deb ;;
        pkg2pacman) pkg2pacman ;;
        vanilla)    ## Build vanilla rTorrent [also un-patches src dirs]
                    prep
                    set_build_env
                    core_unpack
                    build
                    symlink_binary -vanilla
                    check
                    ;;

        *)
            echo >&2 "${BOLD}Usage: $0 (all | clean | clean_all | download | build | check | extend)$OFF"
            echo >&2 "Build rTorrent$VERSION_EXTRAS $RT_VERSION/$LT_VERSION into $(sed -e s:$HOME/:~/: <<<$INSTALL_DIR)"
            echo >&2
            echo >&2 "Custom environment variables:"
            echo >&2 "    CURL_OPTS=\"${CURL_OPTS}\" (e.g. --insecure)"
            echo >&2 "    MAKE_OPTS=\"${MAKE_OPTS}\""
            echo >&2 "    CFG_OPTS=\"${CFG_OPTS}\" (e.g. --enable-debug --enable-extra-debug)"
            echo >&2 "    CFG_OPTS_LT=\"${CFG_OPTS_LT}\" (e.g. --disable-instrumentation for MIPS, PowerPC, ARM)"
            # MIPS | PowerPC | ARM users, read https://github.com/rakshasa/rtorrent/issues/156
            echo >&2 "    CFG_OPTS_RT=\"${CFG_OPTS_RT}\""
            echo >&2
            echo >&2 "Build actions:"
            egrep "(\(\) {|\) +) ##" $0 | grep -v grep | sort \
                                     | sed -r -e "s:^:  :" -e 's:\(\) \{ #:  :' -e 's:\)[^#]+#:  :' \
                                     | sed -r -e "s/#/@/" -e "s/^\s+/  /" | \
            while read i; do
                echo "   " $(eval "echo $i") | sed -e "s/@/\t/"
            done
            exit 1
            ;;
    esac
done
>>>>>>> upstream/master
