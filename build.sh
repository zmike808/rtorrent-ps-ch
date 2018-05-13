#! /usr/bin/env bash
#
# Build rTorrent including patches
#

# Set CH version
RT_CH_MAJOR_VERSION=1.7
RT_CH_MINOR_RELEASE=0
RT_CH_MINOR_GIT=1

# Set latest major lT/rT release versions
LT_MAJOR=0.13
RT_MAJOR=0.9
RT_MINOR=6

# Specify git branch/commit for rTorrent and libTorrent to compile from: [master|15e64bd]
export GIT_LT="c167c5a"         # 2016-12-12 master
export GIT_RT="226e670"         # 2016-10-23 master

# Dependency versions
export CARES_VERSION=1.13.0     # 2017-06
export CURL_VERSION=7.54.1      # 2017-06 ; WARNING: see rT issue #457 regarding curl configure options
export XMLRPC_TREE=stable       # [super-stable | stable | advaced]
export XMLRPC_REV=2912          # Release 1.43.06 2016-12



#
# HERE BE DRAGONS!
#

# Support only git versions of lT/rT (not major releases)
ONLY_GIT_LT_RT=true

# Set main RT/LT variables
export RT_CH_VERSION=$RT_CH_MAJOR_VERSION.$RT_CH_MINOR_RELEASE
export LT_VERSION=$LT_MAJOR.$RT_MINOR;
export RT_VERSION=$RT_MAJOR.$RT_MINOR;

# Let's fake the version number of the git version to be compatible with our patching system
export GIT_MINOR=$[$RT_MINOR + 1]

set_git_env_vars() { # Reset RT/LT env vars if git is used
    export RT_CH_VERSION=$RT_CH_MAJOR_VERSION.$RT_CH_MINOR_GIT
    export LT_VERSION=$LT_MAJOR.$GIT_MINOR
    export RT_VERSION=$RT_MAJOR.$GIT_MINOR
}

# Only support git versions or dealing with optional 2nd "git" argument: update necessary variables
[[ $ONLY_GIT_LT_RT = true ]] || [[ $2 = "git" ]] && set_git_env_vars



# Set source directory
SRC_DIR=$(cd $(dirname $0) && pwd)

# rT-PS-CH variables
RT_CH_TITLE="rTorrent-PS-CH"
export RT_CH_DIRNAME="$(echo $RT_CH_TITLE | tr '[:upper:]' '[:lower:]')"

# Extra options handling (set some overridable defaults)
: ${INSTALL_ROOT:=$HOME}
INST_DIR="$INSTALL_ROOT/lib/$RT_CH_DIRNAME-$RT_CH_VERSION-$RT_VERSION"
: ${ROOT_SYS_DIR:=/usr/local}
: ${ROOT_PKG_DIR:=/opt}
ROOT_SYMLINK_DIR="$ROOT_PKG_DIR/$RT_CH_DIRNAME"
PKG_INST_DIR="$ROOT_SYMLINK_DIR-$RT_CH_VERSION-$RT_VERSION"
TARBALLS_DIR="$SRC_DIR/tarballs"
: ${CURL_OPTS:=-sLS}
: ${CFG_OPTS:=}
: ${CFG_OPTS_LT:=}
: ${CFG_OPTS_RT:=}
: ${OPTIMIZE_BUILD:=yes}
[[ "$OPTIMIZE_BUILD" = yes ]] && : ${MAKE_OPTS:=-j4}
: ${VER_INFO_FILENAME:=version-info.sh}
export INSTALL_ROOT INST_DIR CURL_OPTS CFG_OPTS CFG_OPTS_LT CFG_OPTS_RT MAKE_OPTS TARBALLS_DIR


reset_vanilla_env_vars() { # Reset necessary vars for vanilla build
    VANILLA_POSTFIX="-vanilla"
    RT_CH_DIRNAME="$RT_CH_DIRNAME${VANILLA_POSTFIX}"
    INST_DIR="$INSTALL_ROOT/lib/$RT_CH_DIRNAME-$RT_CH_VERSION-$RT_VERSION"
}


# Fix people's broken systems
[[ "$(tr A-Z a-z <<<${LANG/*.})" = "utf-8" ]] || export LANG=en_US.UTF-8
unset LC_ALL
export LC_ALL

# Select build tools (prefer 'g' variants if available)
command which gmake >/dev/null && export MAKE=gmake || export MAKE=make
command which glibtoolize >/dev/null && export LIBTOOLIZE=glibtoolize || export LIBTOOLIZE=libtoolize

# Set sed command
export SED_I="sed -i -e"

# Debian-like deps, see below for other distros
BUILD_PKG_DEPS=( libncurses5-dev libncursesw5-dev libssl-dev zlib1g-dev libcppunit-dev locales )


# Distro specifics
case $(echo -n "$(lsb_release -sic 2>/dev/null || echo NonLSB)" | tr ' \n' '-') in	#"
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


# Platform magic
case "$(uname -s)" in
    FreeBSD)
        export SED_I="sed -i '' -e"
        ;;
esac

# Check gcc type
if command which dpkg-architecture >/dev/null && dpkg-architecture -earmhf; then
    GCC_TYPE="Raspbian"
elif command which gcc >/dev/null; then
    GCC_TYPE=$(gcc --version | head -n1 | tr -s '()' ' ' | cut -f2 -d' ')	#'
else
    GCC_TYPE=none
fi

# gcc optimization
case "$GCC_TYPE" in
    # Raspberry Pi 2 with one of
    #   gcc (Debian 4.6.3-14+rpi1) 4.6.3
    #   gcc (Raspbian 4.8.2-21~rpi3rpi1) 4.8.2
    Raspbian)
        if uname -a | grep 'armv7' >/dev/null; then
            # gcc optimization
            export CFLAGS="$CFLAGS -march=armv7-a -mfpu=neon-vfpv4 -mfloat-abi=hard -O2 -fomit-frame-pointer"
            export CFG_OPTS_LT="$CFG_OPTS_LT --disable-instrumentation"
            OPTIMIZE_BUILD=yes
        fi
        ;;
    *)
        [[ "$OPTIMIZE_BUILD" = yes ]] && export CFLAGS="-march=native -pipe -O2 -fomit-frame-pointer${CFLAGS:+ }${CFLAGS}"
        ;;
esac


set_compiler_flags() { # Set final compiler flags
    export PKG_CONFIG_PATH="$INST_DIR/lib/pkgconfig${PKG_CONFIG_PATH:+:}${PKG_CONFIG_PATH}"
    export LDFLAGS="-Wl,-rpath,'\$\$ORIGIN/../lib' -Wl,-rpath,'\$\$ORIGIN/../lib/$RT_CH_DIRNAME/lib'${LDFLAGS:+ }${LDFLAGS}"
    [[ -z "${CXXFLAGS+x}" ]] && [[ -z "${CFLAGS+x}" ]] || \
        export CXXFLAGS="${CFLAGS}${CXXFLAGS:+ }${CXXFLAGS}"
}


display_env_vars() { # Display env vars
    echo
    echo "${BOLD}Env for building $RT_CH_TITLE${VANILLA_POSTFIX} $RT_CH_VERSION $RT_VERSION/$LT_VERSION into $INST_DIR$OFF"
    echo
    printf "export OPTIMIZE_BUILD=%q\n"     "${OPTIMIZE_BUILD}"
    printf "export PKG_CONFIG_PATH=%q\n"    "${PKG_CONFIG_PATH}"
    printf "export LDFLAGS=%q\n"            "${LDFLAGS}"
    [[ -z "${CFLAGS+x}" ]] || \
        printf "export CFLAGS=%q\n"         "${CFLAGS}"
    [[ -z "${CXXFLAGS+x}" ]] || \
        printf "export CXXFLAGS=%q\n"       "${CXXFLAGS}"
    echo
    printf 'export INSTALL_ROOT=%q\n'       "$INSTALL_ROOT"
    printf 'export INST_DIR=%q\n'           "$INST_DIR"
    printf 'export PKG_INST_DIR=%q\n'       "$PKG_INST_DIR"
    echo
    printf 'export CURL_OPTS=%q\n'          "$CURL_OPTS"
    printf 'export MAKE_OPTS=%q\n'          "$MAKE_OPTS"
    printf 'export CFG_OPTS=%q\n'           "$CFG_OPTS"
    printf 'export CFG_OPTS_LT=%q\n'        "$CFG_OPTS_LT"
    printf 'export CFG_OPTS_RT=%q\n'        "$CFG_OPTS_RT"
    echo
}



# Sources
SELF_URL=https://github.com/chros73/$RT_CH_DIRNAME.git

TARBALLS=(
"http://c-ares.haxx.se/download/c-ares-$CARES_VERSION.tar.gz"
"http://curl.haxx.se/download/curl-$CURL_VERSION.tar.gz"
"https://dl.bintray.com/chros73/$RT_CH_DIRNAME/pool/x/xmlrpc-c-$XMLRPC_TREE/xmlrpc-c-$XMLRPC_TREE-$XMLRPC_REV-src.tgz"
"https://bintray.com/artifact/download/pyroscope/rtorrent-ps/libtorrent-$LT_VERSION.tar.gz"
"https://bintray.com/artifact/download/pyroscope/rtorrent-ps/rtorrent-$RT_VERSION.tar.gz"
)

# Get xmlrpc-c from svn if it's not mirrored
[[ ! $XMLRPC_REV =~ ^(2912|2775)$ ]] && XMLRPC_SVN_URL="http://svn.code.sf.net/p/xmlrpc-c/code/$XMLRPC_TREE@$XMLRPC_REV"

# Source package md5 hashes
SRC_PKG_HASHES=$(cat <<.
c-ares-1.13.0.tar.gz:d2e010b43537794d8bedfb562ae6bba2
curl-7.54.1.tar.gz:21a6e5658fd55103a90b11de7b2a8a8c
xmlrpc-c-stable-2912-src.tgz:d6336bc1ff6d5ba705438bed72268701
libtorrent-c167c5a.tar.gz:58448dbefe92616f6ad19ac41315feed
rtorrent-226e670.tar.gz:a0138f4739d4313d5dfad0432cabef5c
.
)


# Directory definition
SUBDIRS="c-ares-*[0-9] curl-*[0-9] xmlrpc-c-$XMLRPC_TREE-$XMLRPC_REV libtorrent-*[0-9] rtorrent-*[0-9]"


# Command dependency
BUILD_CMD_DEPS=$(cat <<.
coreutils:md5sum
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
chrpath:chrpath
.
)


set -e
set +x
ESC=$(echo -en \\0033)
BOLD="$ESC[1m"
OFF="$ESC[0m"



#
# HELPERS
#

bold() { # [message] : Display bold message
    echo "$BOLD$1$OFF"
}

fail() { # [message] : Display bold message and exit immediately
    bold "ERROR: $@"
    exit 1
}

clean() { # [package-version] : Clean up generated files in directory of packages
    for i in $SUBDIRS; do
        [[ -n "$1" && ! "$i" = "$1" ]] && continue
        sdir=${i%%-*}
        ( cd $i && $MAKE clean && rm -rf $TARBALLS_DIR/DONE-$sdir >/dev/null )
    done
}

clean_all() { # [package-version] : Remove all created directories in the working directory
    [[ -d $TARBALLS_DIR ]] && [[ -f $TARBALLS_DIR/DONE-PKG ]] && rm -f $TARBALLS_DIR/DONE-PKG >/dev/null
    for i in $SUBDIRS; do
        [[ -n "$1" && ! "$i" = "$1" ]] && continue
        sdir=${i%%-*}
        [[ ! -d $i ]] || rm -rf $i >/dev/null && rm -rf $TARBALLS_DIR/DONE-$sdir >/dev/null
    done
}

check_deps() { # Check command and package dependency
    for dep in $BUILD_CMD_DEPS; do
        pkg=${dep%%:*}
        cmd=${dep##*:}
        if which $cmd >/dev/null; then :; else
            echo "You don't have the '$cmd' command available, you likely need to:"
            bold "    sudo apt-get install $pkg"
            exit 1
        fi
    done

    local have_dep=''
    local installer=''

    if which dpkg >/dev/null; then
        have_dep='dpkg -l'
        installer='apt-get install'
    elif which pacman >/dev/null; then
        have_dep='pacman -Q'
        installer='pacman -S'
    fi

    if [[ -n "$installer" ]]; then
        for dep in "${BUILD_PKG_DEPS[@]}"; do
            if ! $have_dep "$dep" >/dev/null; then
                echo "You don't have the '$dep' package installed, you likely need to:"
                bold "    sudo $installer $dep"
                exit 1
            fi
        done
    fi
}

prep() { # Check dependency and create basic directories
    check_deps
    mkdir -p "$INSTALL_ROOT/bin"
    mkdir -p $INST_DIR/{bin,include,lib,man,share}
    mkdir -p $TARBALLS_DIR
}

check_hash() { # [package-version.tar.gz] : md5 hashcheck downloaded packages
    for srchash in ${SRC_PKG_HASHES[@]}; do
        pkg=${srchash%%:*}
        hash=${srchash##*:}

        if [ "$1" == "$pkg" ]; then
            echo "$hash  $TARBALLS_DIR/$pkg" | md5sum -c --status 2>/dev/null && break
            rm -f "$TARBALLS_DIR/$pkg" && fail "Checksum failed for $pkg"
        fi
    done
}

download() { # [package-version] : Download and unpack sources
    [[ -d $TARBALLS_DIR ]] && [[ -f $TARBALLS_DIR/DONE-PKG ]] && rm -f $TARBALLS_DIR/DONE-PKG >/dev/null

    if [ -n "$XMLRPC_SVN_URL" ]; then
        # getting xmlrpc-c from SVN
        [[ -d xmlrpc-c-$XMLRPC_TREE-$XMLRPC_REV ]] || [[ -n "$1" && "xmlrpc-c-$XMLRPC_TREE-$XMLRPC_REV" = "$1" || -z ${1+x} ]] \
            && ( echo "Getting xmlrpc-c r$XMLRPC_REV" && svn -q checkout "$XMLRPC_SVN_URL" xmlrpc-c-$XMLRPC_TREE-$XMLRPC_REV \
                 || fail "xmlrpc-c-$XMLRPC_TREE-$XMLRPC_REV could not be checked out from SVN.")
    fi

    for url in "${TARBALLS[@]}"; do
        url_base=${url##*/}
        # skip downloading here xmlrpc-c for svn, rtorrent and libtorrent if git version should be used
        [ -z "${url_base##*xmlrpc*}" ] && [ -n "$XMLRPC_SVN_URL" ] && continue
        [ -z "${url_base##*rtorrent*}" ] && [ "$RT_VERSION" = "$RT_MAJOR.$GIT_MINOR" ] && continue
        [ -z "${url_base##*libtorrent*}" ] && [ "$RT_VERSION" = "$RT_MAJOR.$GIT_MINOR" ] && continue
        tarball_dir=${url_base%.tar.gz}
        tarball_dir=${tarball_dir%-src.tgz}
        [[ -n "$1" && ! "$tarball_dir" = "$1" ]] && continue
        [[ -f $TARBALLS_DIR/${url_base} ]] || ( echo "Getting $url_base" && command cd $TARBALLS_DIR && curl -O $CURL_OPTS $url )
        [[ -d $tarball_dir ]] || ( check_hash "${url_base}" && echo "Unpacking ${url_base}" && tar xfz $TARBALLS_DIR/${url_base} || fail "Tarball ${url_base} could not be unpacked." )
    done

    if [ "$RT_VERSION" = "$RT_MAJOR.$GIT_MINOR" ]; then
        # getting rtorrent and libtorrent from GitHub
        if [ -z ${1+x} ]; then
            download_git rakshasa libtorrent $GIT_LT
            download_git rakshasa rtorrent $GIT_RT
        elif [ "rtorrent-$GIT_RT" = "$1" ]; then
            download_git rakshasa rtorrent $GIT_RT
        elif [ "libtorrent-$GIT_LT" = "$1" ]; then
            download_git rakshasa libtorrent $GIT_LT
        fi
    fi

    touch $TARBALLS_DIR/DONE-PKG
}

download_git() { # owner project commit|branch : Download from GitHub
    owner="$1"; repo="$2"; repo_ver="$3";
    url="https://github.com/$owner/$repo/archive/$repo_ver.tar.gz"
    [[ -f $TARBALLS_DIR/$repo-$repo_ver.tar.gz ]] || ( echo "Getting $repo-$repo_ver.tar.gz" && command cd $TARBALLS_DIR && curl $CURL_OPTS -o $repo-$repo_ver.tar.gz $url )
    [[ -d $repo-$repo_ver* ]] || ( check_hash "$repo-$repo_ver.tar.gz" && echo "Unpacking $repo-$repo_ver.tar.gz" && tar xfz $TARBALLS_DIR/$repo-$repo_ver.tar.gz || fail "Tarball $repo-$repo_ver.tar.gz could not be unpacked.")
    [ $repo == "rtorrent" ] && mv $repo-$repo_ver* $repo-$RT_VERSION || mv $repo-$repo_ver* $repo-$LT_VERSION
}

build_cares() { # Build direct dependency: c-ares
    [[ -e $TARBALLS_DIR/DONE-PKG ]] || fail "You need to '$0 download' first!"
    [[ -d $TARBALLS_DIR ]] && [[ -f $TARBALLS_DIR/DONE-c ]] && rm -f $TARBALLS_DIR/DONE-c >/dev/null

    bold "~~~~~~~~~~~~~~~~~~~~~~~~   Building c-ares   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    ( set +x ; cd c-ares-$CARES_VERSION \
        && ./configure --prefix=$INST_DIR \
        && $MAKE $MAKE_OPTS \
        && $MAKE install \
        || fail "during building 'c-ares'!" )

    touch $TARBALLS_DIR/DONE-c
}

build_curl() { # Build direct dependency: curl
    [[ -e $TARBALLS_DIR/DONE-PKG ]] && [[ -f $TARBALLS_DIR/DONE-c ]] || fail "You need to build 'c-ares' first!"
    [[ -d $TARBALLS_DIR ]] && [[ -f $TARBALLS_DIR/DONE-curl ]] && rm -f $TARBALLS_DIR/DONE-curl >/dev/null

    bold "~~~~~~~~~~~~~~~~~~~~~~~~   Building curl   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    ( set +x ; cd curl-$CURL_VERSION \
        && ./configure --prefix=$INST_DIR --enable-ares=$INST_DIR --with-ssl --without-nss --without-libssh2 --without-librtmp --without-libidn2 \
             --disable-ntlm-wb --disable-sspi --disable-threaded-resolver --disable-libcurl-option --disable-manual --disable-gopher --disable-smtp --disable-file \
             --disable-smb --disable-imap --disable-pop3 --disable-tftp --disable-telnet --disable-dict --disable-rtsp --disable-ldap --disable-ftp \
        && $MAKE $MAKE_OPTS \
        && $MAKE install \
        && chrpath -r "\$ORIGIN/../lib:\$ORIGIN/../lib/$RT_CH_DIRNAME/lib" "$INST_DIR/lib/libcurl.so" \
        || fail "during building 'curl'!" )

    touch $TARBALLS_DIR/DONE-curl
}

build_xmlrpc() { # Build direct dependency: xmlrpc-c
    [[ -e $TARBALLS_DIR/DONE-PKG ]] || fail "You need to '$0 download' first!"
    [[ -d $TARBALLS_DIR ]] && [[ -f $TARBALLS_DIR/DONE-xmlrpc ]] && rm -f $TARBALLS_DIR/DONE-xmlrpc >/dev/null

    bold "~~~~~~~~~~~~~~~~~~~~~~~~   Building xmlrpc-c   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    ( set +x ; cd xmlrpc-c-$XMLRPC_TREE-$XMLRPC_REV \
        && ./configure --prefix=$INST_DIR --with-libwww-ssl --disable-wininet-client --disable-curl-client --disable-libwww-client --disable-abyss-server \
             --disable-cgi-server --disable-cplusplus \
        && $MAKE $MAKE_OPTS \
        && $MAKE install \
        || fail "during building 'xmlrpc-c'!" )

    touch $TARBALLS_DIR/DONE-xmlrpc
}

build_deps() { # Build direct dependencies: c-ares, curl, xmlrpc-c
    build_cares
    build_curl
    build_xmlrpc
}

build_lt() { # Build libTorrent
    [[ -e $TARBALLS_DIR/DONE-PKG ]] || fail "You need to '$0 download' first!"
    [[ -d $TARBALLS_DIR ]] && [[ -f $TARBALLS_DIR/DONE-libtorrent ]] && rm -f $TARBALLS_DIR/DONE-libtorrent >/dev/null

    bold "~~~~~~~~~~~~~~~~~~~~~~~~   Building libTorrent   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    ( set +x ; cd libtorrent-$LT_VERSION \
        && ./autogen.sh \
        && ./configure --prefix=$INST_DIR $CFG_OPTS $CFG_OPTS_LT \
        && $MAKE $MAKE_OPTS \
        && $MAKE install \
        || fail "during building 'libtorrent'!" )

    touch $TARBALLS_DIR/DONE-libtorrent
}

build_rt() { # Build rTorrent
    [[ -e $TARBALLS_DIR/DONE-PKG ]] && [[ -f $TARBALLS_DIR/DONE-c ]] && [[ -f $TARBALLS_DIR/DONE-curl ]] && [[ -f $TARBALLS_DIR/DONE-xmlrpc ]] && [[ -f $TARBALLS_DIR/DONE-libtorrent ]] || fail "You need to build 'c-ares', 'curl', 'xmlrpc-c', 'libtorrent' first!"
    [[ -d $TARBALLS_DIR ]] && [[ -f $TARBALLS_DIR/DONE-rtorrent ]] && rm -f $TARBALLS_DIR/DONE-rtorrent >/dev/null

    bold "~~~~~~~~~~~~~~~~~~~~~~~~   Building rTorrent   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    ( set +x ; cd rtorrent-$RT_VERSION \
        && ./autogen.sh \
        && ./configure --prefix=$INST_DIR $CFG_OPTS $CFG_OPTS_RT --with-ncursesw --with-xmlrpc-c=$INST_DIR/bin/xmlrpc-c-config \
        && $MAKE $MAKE_OPTS \
        && $MAKE install \
        && chrpath -r "\$ORIGIN/../lib:\$ORIGIN/../lib/$RT_CH_DIRNAME/lib" "$INST_DIR/bin/rtorrent" \
        || fail "during building 'rtorrent'!" )

    touch $TARBALLS_DIR/DONE-rtorrent
}

build_lt_rt() { # Build libTorrent and rTorrent
    build_lt
    build_rt
}

patch_lt_vanilla() { # Patch vanilla libTorrent
    [[ -e $TARBALLS_DIR/DONE-PKG ]] && [[ -d libtorrent-$LT_VERSION ]] || fail "You need to '$0 download' first!"

    bold "~~~~~~~~~~~~~~~~~~~~~~~~   Patching vanilla libTorrent   ~~~~~~~~~~~~~~~~~~~~~~~~~~"

    # Patch vanilla libTorrent
    pushd libtorrent-$LT_VERSION

    for vanilla in $SRC_DIR/patches/vanilla_{*${LT_VERSION%-svn}*,all}_*.patch; do
        [[ ! -e "$vanilla" ]] || { bold "$(basename $vanilla)"; patch -uNp0 -i "$vanilla"; }
    done

    popd
}

patch_rt_vanilla() { # Patch vanilla rTorrent
    [[ -e $TARBALLS_DIR/DONE-PKG ]] && [[ -d rtorrent-$RT_VERSION ]] || fail "You need to '$0 download' first!"

    bold "~~~~~~~~~~~~~~~~~~~~~~~~   Patching vanilla rTorrent   ~~~~~~~~~~~~~~~~~~~~~~~~~~"

    # Patch vanilla rTorrent
    pushd rtorrent-$RT_VERSION

    for vanilla in $SRC_DIR/patches/vanilla_{*${RT_VERSION%-svn}*,all}_*.patch; do
        [[ ! -e "$vanilla" ]] || { bold "$(basename $vanilla)"; patch -uNp0 -i "$vanilla"; }
    done

    popd
}

patch_lt() { # Patch libTorrent
    [[ -e $TARBALLS_DIR/DONE-PKG ]] && [[ -d libtorrent-$LT_VERSION ]] || fail "You need to '$0 download' first!"

    patch_lt_vanilla

    bold "~~~~~~~~~~~~~~~~~~~~~~~~   Patching libTorrent   ~~~~~~~~~~~~~~~~~~~~~~~~~~"

    # Patch libTorrent
    pushd libtorrent-$LT_VERSION

    for corepatch in $SRC_DIR/patches/lt-ps_{*${LT_VERSION%-svn}*,all}_*.patch; do
        [[ ! -e "$corepatch" ]] || { bold "$(basename $corepatch)"; patch -uNp0 -i "$corepatch"; }
    done

    for backport in $SRC_DIR/patches/{backport,misc}_{*${LT_VERSION%-svn}*,all}_*.patch; do
        [[ ! -e "$backport" ]] || { bold "$(basename $backport)"; patch -uNp0 -i "$backport"; }
    done

    popd
}

patch_rt() { # Patch rTorrent
    [[ -e $TARBALLS_DIR/DONE-PKG ]] && [[ -d rtorrent-$RT_VERSION ]] || fail "You need to '$0 download' first!"

    patch_rt_vanilla

    bold "~~~~~~~~~~~~~~~~~~~~~~~~   Patching rTorrent   ~~~~~~~~~~~~~~~~~~~~~~~~~~"

    # Patch rTorrent
    pushd rtorrent-$RT_VERSION

    for corepatch in $SRC_DIR/patches/ps-*_{*${RT_VERSION%-svn}*,all}.patch; do
        [[ ! -e "$corepatch" ]] || { bold "$(basename $corepatch)"; patch -uNp1 -i "$corepatch"; }
    done

    for backport in $SRC_DIR/patches/{backport,misc}_*${RT_VERSION%-svn}*_*.patch; do
        [[ ! -e "$backport" ]] || { bold "$(basename $backport)"; patch -uNp0 -i "$backport"; }
    done

    ${NOPYROP:-false} || for pyropatch in $SRC_DIR/patches/pyroscope_{*${RT_VERSION%-svn}*,all}.patch; do
        [[ ! -e "$pyropatch" ]] || { bold "$(basename $pyropatch)"; patch -uNp1 -i "$pyropatch"; }
    done

    ${NOPYROP:-false} || for i in "$SRC_DIR"/patches/*.{cc,h}; do
        ln -nfs $i src
    done

    ${NOPYROP:-false} || for uipyropatch in $SRC_DIR/patches/ui_pyroscope_{*${RT_VERSION%-svn}*,all}.patch; do
        [[ ! -e "$uipyropatch" ]] || { bold "$(basename $uipyropatch)"; patch -uNp1 -i "$uipyropatch"; }
    done

    # Version handling
    RT_HEX_VERSION=$(printf "0x%02X%02X%02X" ${RT_VERSION//./ })
    ${NOPYROP:-false} || $SED_I "s:\\(AC_DEFINE(HAVE_CONFIG_H.*\\):\1  AC_DEFINE(RT_HEX_VERSION, $RT_HEX_VERSION, for CPP if checks):" configure.ac

    [[ "$OPTIMIZE_BUILD" = yes ]] && CH_SEPARATOR="+" || CH_SEPARATOR="-"
    ${NOPYROP:-false} || $SED_I "s%rTorrent \\\" VERSION \\\"/\\\"%$RT_CH_TITLE $RT_CH_VERSION $RT_VERSION/$LT_VERSION $CH_SEPARATOR \\\"%" src/ui/download_list.cc
    ${NOPYROP:-false} || $SED_I "s%std::string(torrent::version()) + \\\" - \\\" +%%" src/ui/download_list.cc
    popd
}

patch_lt_rt_vanilla() { # Patch vanilla libTorrent and rTorrent
    patch_lt_vanilla
    patch_rt_vanilla
}

patch_lt_rt() { # Patch libTorrent and rTorrent
    patch_lt
    patch_rt
}

clean_up() { # Remove unnecessary files from compilation dir
    rm -rf "$INST_DIR/"{lib/*.a,lib/*.la,lib/pkgconfig,share/man,man,share,include,bin/curl,bin/*-config}
}

add_version_info() { # Display version info
    [[ -d "$INST_DIR/" ]] || fail "Could not locate dir '$INST_DIR'"
    cat >"$INST_DIR/$VER_INFO_FILENAME" <<.
RT_CH_VERSION=$RT_CH_VERSION${VANILLA_POSTFIX}
RT_PS_VERSION=$RT_VERSION
RT_PS_LT_VERSION=$LT_VERSION
RT_PS_REVISION=$(date +'%Y%m%d')-$(git rev-parse --short HEAD)
RT_PS_CARES_VERSION=$CARES_VERSION
RT_PS_CURL_VERSION=$CURL_VERSION
RT_PS_XMLRPC_TREE=$XMLRPC_TREE
RT_PS_XMLRPC_REV=$XMLRPC_REV
OPTIMIZED_BUILD=$OPTIMIZE_BUILD
.
}

symlink_binary_home() { # Symlink binary in HOME
    [[ ! -f "$INST_DIR/bin/rtorrent" ]] && fail "Compilation hasn't been finished, try it again."

    cd "$INSTALL_ROOT/lib"
    ln -nfs "$RT_CH_DIRNAME-$RT_CH_VERSION-$RT_VERSION" "$RT_CH_DIRNAME"
    cd "$INSTALL_ROOT/bin"
    ln -nfs "../lib/$RT_CH_DIRNAME/bin/rtorrent" "rtorrent${VANILLA_POSTFIX}"
    cd "$SRC_DIR"
}

symlink_binary_inst() { # Symlink binary after it's installed into $ROOT_PKG_DIR dir
    [[ ! -f "$PKG_INST_DIR/bin/rtorrent" ]] && fail "Installation hasn't been finished, try it again."
    [[ -f "$ROOT_SYS_DIR/bin/rtorrent" ]] && [[ ! -L "$ROOT_SYS_DIR/bin/rtorrent" ]] && fail "Could not create symlink 'rtorrent' in '$ROOT_SYS_DIR/bin/'"
    [[ -d "$ROOT_SYS_DIR/lib/$RT_CH_DIRNAME" || -f "$ROOT_SYS_DIR/lib/$RT_CH_DIRNAME" ]] && [[ ! -L "$ROOT_SYS_DIR/lib/$RT_CH_DIRNAME" ]] && fail "Could not create symlink '$RT_CH_DIRNAME' in '$ROOT_SYS_DIR/lib/'"
    [[ -d "$ROOT_SYMLINK_DIR" || -f "$ROOT_SYMLINK_DIR" ]] && [[ ! -L "$ROOT_SYMLINK_DIR" ]] && fail "Could not create symlink '$RT_CH_DIRNAME' in '$ROOT_PKG_DIR/'"

    ln -nfs "$ROOT_SYMLINK_DIR" "$ROOT_SYS_DIR/lib/$RT_CH_DIRNAME"
    ln -nfs "$ROOT_SYMLINK_DIR/bin/rtorrent" "$ROOT_SYS_DIR/bin/rtorrent"
    cd "$ROOT_PKG_DIR"
    ln -nfs "$RT_CH_DIRNAME-$RT_CH_VERSION-$RT_VERSION" "$RT_CH_DIRNAME"
    cd "$SRC_DIR"
}

check() { # root_dir : Print some diagnostic success indicators
    if [ "$1" == "$HOME" ]; then
        echo "$1/lib/$RT_CH_DIRNAME" "->" $(readlink $1/lib/$RT_CH_DIRNAME) | sed -e "s:$1:~:g"
        echo "$1/bin/rtorrent${VANILLA_POSTFIX}" "->" $(readlink $1/bin/rtorrent${VANILLA_POSTFIX}) | sed -e "s:$1:~:g"
    else
        echo "$ROOT_SYMLINK_DIR" "->" $(readlink $ROOT_SYMLINK_DIR)
        echo "$1/lib/$RT_CH_DIRNAME" "->" $(readlink $1/lib/$RT_CH_DIRNAME)
        echo "$1/bin/rtorrent" "->" $(readlink $1/bin/rtorrent)
    fi

    # This first selects the rpath dependencies, and then filters out libs found in the install dirs.
    # If anything is left, we have an external dependency that sneaked in.
    echo
    echo -n "Check that static linking worked: "
        libs=$(ldd "$1/bin/rtorrent${VANILLA_POSTFIX}" | egrep "lib(cares|curl|xmlrpc|torrent)")		#"
    if [[ "$(echo "$libs" | egrep -v "$1/bin" | wc -l)" -eq 0 ]]; then
        echo OK; echo
    else
        echo FAIL; echo; echo "Suspicious library paths are:"
        echo "$libs" | egrep -v "$1/bin" || :
        echo
    fi

    echo "Dependency library paths:"
    echo "$libs" | sed -e "s:$1/bin/::g"
}

install() { # Install (copy) to $PKG_INST_DIR
    [[ ! -f "$INST_DIR/$VER_INFO_FILENAME" ]] && fail "Compilation hasn't been finished, try it again."
    [[ -d "$PKG_INST_DIR" ]] && [[ -f "$PKG_INST_DIR/bin/rtorrent" ]] && fail "Could not clean install into dir '$PKG_INST_DIR', dir already exists."

    cp -r "$INST_DIR" "$ROOT_PKG_DIR/" || fail "Could not copy into dir '$PKG_INST_DIR', have you tried with 'sudo'?"
    chmod -R a+rX "$PKG_INST_DIR/"
}

package_prep() { # make $PACKAGE_ROOT lean and mean
    [[ -n "$DEBFULLNAME" ]] || fail "You MUST set DEBFULLNAME in your environment"
    [[ -n "$DEBEMAIL" ]] || fail "You MUST set DEBEMAIL in your environment"

    [[ -d "$PKG_INST_DIR" ]] && [[ -f "$PKG_INST_DIR/bin/rtorrent" ]] || fail "Could not package '$PKG_INST_DIR', it has to be 'install'-ed first."
    [[ ! -f "$PKG_INST_DIR/$VER_INFO_FILENAME" ]] && fail "Could not package '$PKG_INST_DIR', there's no '$VER_INFO_FILENAME' file."

    . "$PKG_INST_DIR/$VER_INFO_FILENAME"

    [[ "$OPTIMIZED_BUILD" = yes ]] && fail "Could not package optimized build, it has to be compiled with 'OPTIMIZE_BUILD=no ./build.sh ch' first."

    DIST_DIR="/tmp/$RT_CH_DIRNAME-dist"
    rm -rf "$DIST_DIR" && mkdir -p "$DIST_DIR"
}

call_fpm() { # command_line_params : Helper function for pkg2* functions
    fpm -s dir -n "${fpm_pkg_name:-$RT_CH_DIRNAME}" \
        -v "$RT_CH_VERSION-$RT_PS_VERSION" --iteration "$fpm_iteration" \
        -m "\"$DEBFULLNAME\" <$DEBEMAIL>" \
        --license "$fpm_license" --vendor "https://github.com/rakshasa , https://github.com/pyroscope/rtorrent-ps#rtorrent-ps" \
        --description "Patched and extended ncurses BitTorrent client" \
        --url "https://github.com/chros73/$RT_CH_DIRNAME#$RT_CH_DIRNAME-fork-notes" \
        "$@" -C "$PKG_INST_DIR/." --prefix "$PKG_INST_DIR" '.'
    chmod a+rX .
    chmod a+r  *".$fpm_pkg_ext"
}

pkg2deb() { # Package current $PKG_INST_DIR installation for APT [needs fpm]
    # You need to:
    #   aptitude install ruby ruby-dev
    #   gem install fpm
    #   which fpm || ln -s $(ls -1 /var/lib/gems/*/bin/fpm | tail -1) /usr/local/bin

    package_prep

    fpm_pkg_ext="deb"
    fpm_iteration="$RT_PS_REVISION~"$(lsb_release -cs)
    fpm_license="GPL v2"
    deps=$(ldd "$PKG_INST_DIR/bin/rtorrent" | cut -f2 -d'>' | cut -f2 -d' ' | egrep '^/lib/|^/usr/lib/' \
        | sed -r -e 's:^/lib.+:&\n/usr&:' | xargs -n1 dpkg 2>/dev/null -S \
        | cut -f1 -d: | sort -u | xargs -n1 echo '-d')

    ( cd "$DIST_DIR" && call_fpm -t deb --category "net" $deps )

    dpkg-deb -c       "$DIST_DIR"/*".$fpm_pkg_ext"
    echo "~~~" $(find "$DIST_DIR"/*".$fpm_pkg_ext")
    dpkg-deb -I       "$DIST_DIR"/*".$fpm_pkg_ext"
}

pkg2pacman() { # Package current $PKG_INST_DIR installation for PACMAN [needs fpm]
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



#
# MAIN
#
cd "$SRC_DIR"
case "$1" in
    ch)         ## Build all components into $(sed -e s:$HOME/:~/: <<<$INST_DIR)
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
                check "$HOME"
                ;;
    install)    ## Install $(sed -e s:$HOME/:~/: <<<$INST_DIR) compilation into $PKG_INST_DIR
                install
                symlink_binary_inst
                check "$ROOT_SYS_DIR"
                ;;
    pkg2deb)    ## Package $PKG_INST_DIR installation for APT [needs fpm]
                pkg2deb ;;
    pkg2pacman) ## Package $PKG_INST_DIR installation for PACMAN [needs fpm]
                pkg2pacman ;;
    vanilla)    ## Build all vanilla components into $(sed -e s:$HOME/:~/: <<<$INSTALL_ROOT/lib/$RT_CH_DIRNAME-vanilla-$RT_CH_VERSION-$RT_VERSION)
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
                check "$HOME"
                ;;

    # Dev related actions
    env-vars)   set_compiler_flags; display_env_vars ;;
    clean)      clean ;;
    clean_all)  clean_all ;;
    download)   prep; download ;;
    build-ares) set_compiler_flags; display_env_vars; prep; clean_all "c-ares-$CARES_VERSION"; download "c-ares-$CARES_VERSION"; build_cares ;;
    build-curl) set_compiler_flags; display_env_vars; prep; clean_all "curl-$CURL_VERSION"; download "curl-$CURL_VERSION"; build_curl ;;
    build-xrpc) set_compiler_flags; display_env_vars; prep; clean_all "xmlrpc-c-$XMLRPC_TREE-$XMLRPC_REV"; download "xmlrpc-c-$XMLRPC_TREE-$XMLRPC_REV"; build_xmlrpc ;;
    deps)       set_compiler_flags; display_env_vars; prep; build_deps ;;
    patch-d-lt) NOPYROP=true; display_env_vars; clean_all "libtorrent-$LT_VERSION"; download "libtorrent-$GIT_LT"; patch_lt ;;
    patch-d-rt) NOPYROP=true; display_env_vars; clean_all "rtorrent-$RT_VERSION"; download "rtorrent-$GIT_RT"; patch_rt ;;
    patch-lt)   display_env_vars; clean_all "libtorrent-$LT_VERSION"; download "libtorrent-$GIT_LT"; patch_lt ;;
    patch-rt)   display_env_vars; clean_all "rtorrent-$RT_VERSION"; download "rtorrent-$GIT_RT"; patch_rt ;;
    patch-ltrt) display_env_vars; clean_all "libtorrent-$LT_VERSION"; download "libtorrent-$GIT_LT"; clean_all "rtorrent-$RT_VERSION"; download "rtorrent-$GIT_RT"; patch_lt_rt ;;
    build-lt)   set_compiler_flags; display_env_vars; build_lt ;;
    build-rt)   set_compiler_flags; display_env_vars; build_rt ;;
    build-ltrt) set_compiler_flags; display_env_vars; build_lt_rt ;;
    patchbuild) set_compiler_flags; display_env_vars; clean_all "libtorrent-$LT_VERSION"; download "libtorrent-$GIT_LT"; clean_all "rtorrent-$RT_VERSION"; download "rtorrent-$GIT_RT"; patch_lt_rt; build_lt_rt; add_version_info ;;
    clean-up)   clean_up ;;
    ver-info)   add_version_info ;;
    sm-home)    symlink_binary_home ;;
    sm-inst)    symlink_binary_inst ;;
    check-home) check "$HOME" ;;
    check-inst) check "$ROOT_SYS_DIR" ;;
    *)
        echo >&2 "${BOLD}Usage: $0 (ch [git] | install [git] | pkg2deb [git] | pkg2pacman [git] | vanilla [git])$OFF"
        echo >&2 "Build $RT_CH_TITLE $RT_CH_VERSION $RT_VERSION/$LT_VERSION into $(sed -e s:$HOME/:~/: <<<$INST_DIR)"
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
        grep ").\+##" $0 | grep -v grep | sed -e "s:^:  :" -e "s:): :" -e "s:## ::" | while read i; do
            eval "echo \"   $i\""
        done
        exit 1
        ;;
esac
