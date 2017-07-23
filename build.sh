#! /usr/bin/env bash
#
# Build rTorrent including patches
#

ONLYSUPPORTGITVERSION=true

RT_CH_MAJOR_VERSION=1.5
RT_CH_MINOR_RELEASE=0
RT_CH_MINOR_GIT=3

export RT_MAJOR=0.9
export LT_MAJOR=0.13
export RT_MINOR=6

# specify git branch/commit for rtorrent and libtorrent to compile from: [master|15e64bd]
export GIT_RT="226e670"  # 2016-10-23
export GIT_LT="c167c5a"  # 2016-12-12


export RT_CH_VERSION=$RT_CH_MAJOR_VERSION.$RT_CH_MINOR_RELEASE
export LT_VERSION=$LT_MAJOR.$RT_MINOR;
export RT_VERSION=$RT_MAJOR.$RT_MINOR;

# let's fake the version number of the git version to be compatible with our patching system
export GIT_MINOR=$[$RT_MINOR + 1]

set_git_env_vars() {
    export RT_CH_VERSION=$RT_CH_MAJOR_VERSION.$RT_CH_MINOR_GIT
    export LT_VERSION=$LT_MAJOR.$GIT_MINOR
    export RT_VERSION=$RT_MAJOR.$GIT_MINOR
}

# Only support git version or dealing with optional 2nd "git" argument: update necessary variables
[[ $ONLYSUPPORTGITVERSION = true ]] || [[ $2 = "git" ]] && set_git_env_vars


# Debian-like deps, see below for other distros
BUILD_PKG_DEPS=( libncurses5-dev libncursesw5-dev libssl-dev libcppunit-dev locales unzip )

# Fitting / tested dependency versions for major platforms
export CARES_VERSION=1.13.0 # 2017-06
export CURL_VERSION=7.54.1  # 2017-06
export XMLRPC_REV=2775      # Release 1.43.01 2015-10
# WARNING: see rT issue #457 regarding curl configure options

# Extra options handling (set overridable defaults)
: ${INSTALL_ROOT:=$HOME}
export ROOT_SYMLINK_DIR="/opt/rtorrent"
export PKG_INST_DIR="$ROOT_SYMLINK_DIR-$RT_VERSION-$RT_CH_VERSION"
export INST_DIR="$INSTALL_ROOT/lib/rtorrent-$RT_VERSION-$RT_CH_VERSION"
export BIN_DIR="$INSTALL_ROOT/bin"
: ${CURL_OPTS:=-sLS}
: ${MAKE_OPTS:=}
: ${CFG_OPTS:=}
: ${CFG_OPTS_LT:=}
: ${CFG_OPTS_RT:=}
export INSTALL_ROOT CURL_OPTS MAKE_OPTS CFG_OPTS CFG_OPTS_LT CFG_OPTS_RT

# Distro specifics
case $(echo -n "$(lsb_release -sic 2>/dev/null || echo NonLSB)" | tr ' \n' '-') in	#"
    *-precise|*-trusty|*-utopic|*-wheezy)
        ;;
    *-jessie)
        export CARES_VERSION=1.10.0
        export CURL_VERSION=7.38.0
        ;;
    *-vivid|*-wily|*-xenial|*-yakkety)
        ;;
    *-stretch|*-zesty)
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

# Try this when you get configure errors regarding xmlrpc-c
# ... on a Intel PC type system with certain types of CPUs:
#export CFLAGS="$CFLAGS -march=i586"
if command which dpkg-architecture >/dev/null && dpkg-architecture -earmhf; then
    GCC_TYPE="Raspbian"
elif command which gcc >/dev/null; then
    GCC_TYPE=$(gcc --version | head -n1 | tr -s '()' ' ' | cut -f2 -d' ')	#'
    # Fix libtorrent bug with gcc version >= 6 and set CXXFLAGS env var
    GCC_MAIN_VER=$(gcc --version | head -n1 | cut -d' ' -f4 | cut -d'.' -f1)
    [[ -z "$GCC_MAIN_VER" ]] || [[ $GCC_MAIN_VER -gt 5 ]] && export FIX_LT_GCC_BUG="yes"
else
    GCC_TYPE=none
fi
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


#
# HERE BE DRAGONS!
#

# Fix people's broken systems
test "$(tr A-Z a-z <<<${LANG/*.})" = "utf-8" || export LANG=en_US.UTF-8
unset LC_ALL
export LC_ALL

# Select build tools (prefer 'g' variants if there)
command which gmake && export MAKE=gmake || export MAKE=make
command which glibtoolize && export LIBTOOLIZE=glibtoolize || export LIBTOOLIZE=libtoolize

# Platform magic
export SED_I="sed -i -e"
case "$(uname -s)" in
    FreeBSD)
        export CFLAGS="-pipe -O2 -pthread${CFLAGS:+ }${CFLAGS}"
        export LDFLAGS="-s -lpthread${LDFLAGS:+ }${LDFLAGS}"
        export SED_I="sed -i '' -e"
        ;;
    Linux)
        # gcc optimization, possible "-march" values: https://gcc.gnu.org/onlinedocs/gcc-4.8.4/gcc/i386-and-x86-64-Options.html
#        export CFLAGS="-march=core2 -pipe -O2 -fomit-frame-pointer${CFLAGS:+ }${CFLAGS}"
        export CPPFLAGS="-pthread${CPPFLAGS:+ }${CPPFLAGS}"
        export LIBS="-lpthread${LIBS:+ }${LIBS}"
        ;;
esac

set_build_env() {
    export CPPFLAGS="-I $INST_DIR/include${CPPFLAGS:+ }${CPPFLAGS}"
    export CFLAGS="${CFLAGS}"
    export CXXFLAGS="${CFLAGS}${CXXFLAGS:+ }${CXXFLAGS}"
    export LDFLAGS="-L$INST_DIR/lib -Wl,-rpath,'\$\$ORIGIN/../lib'${LDFLAGS:+ }${LDFLAGS}"
    export LIBS="${LIBS}"
    export PKG_CONFIG_PATH="$INST_DIR/lib/pkgconfig${PKG_CONFIG_PATH:+:}${PKG_CONFIG_PATH}"

    echo "!!! Installing rTorrent $RT_CH_VERSION-$RT_VERSION into $INST_DIR !!!"; echo

    printf "export CPPFLAGS=%q\n"           "${CPPFLAGS}"
    printf "export CFLAGS=%q\n"             "${CFLAGS}"
    printf "export CXXFLAGS=%q\n"           "${CXXFLAGS}"
    printf "export LDFLAGS=%q\n"            "${LDFLAGS}"
    printf "export LIBS=%q\n"               "${LIBS}"
    printf "export PKG_CONFIG_PATH=%q\n"    "${PKG_CONFIG_PATH}"
    printf "export FIX_LT_GCC_BUG=%q\n"     "${FIX_LT_GCC_BUG}"
}

SELF_URL=https://github.com/chros73/rtorrent-ps.git
XMLRPC_URL="http://svn.code.sf.net/p/xmlrpc-c/code/advanced@$XMLRPC_REV"
TARBALLS=(
"http://c-ares.haxx.se/download/c-ares-$CARES_VERSION.tar.gz"
"http://curl.haxx.se/download/curl-$CURL_VERSION.tar.gz"
)

XMLRPC_SVN=true
case $XMLRPC_REV in
    2775|2366|2626)
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
export SRC_DIR=$(cd $(dirname $0) && pwd)
SUBDIRS="c-ares-*[0-9] curl-*[0-9] xmlrpc-c-advanced-$XMLRPC_REV libtorrent-*[0-9] rtorrent-*[0-9]"
ESC=$(echo -en \\0033)
BOLD="$ESC[1m"
OFF="$ESC[0m"

echo "${BOLD}Env for building rTorrent $RT_VERSION/$LT_VERSION$OFF"
printf 'export PKG_INST_DIR=%q\n'   "$PKG_INST_DIR"
printf 'export INSTALL_ROOT=%q\n'   "$INSTALL_ROOT"
printf 'export INST_DIR=%q\n'       "$INST_DIR"
printf 'export BIN_DIR=%q\n'        "$BIN_DIR"
printf 'export CURL_OPTS=%q\n'      "$CURL_OPTS"
printf 'export MAKE_OPTS=%q\n'      "$MAKE_OPTS"
printf 'export CFG_OPTS=%q\n'       "$CFG_OPTS"
printf 'export CFG_OPTS_LT=%q\n'    "$CFG_OPTS_LT"
printf 'export CFG_OPTS_RT=%q\n'    "$CFG_OPTS_RT"
echo


#
# HELPERS
#
bold() {
    echo "$BOLD$1$OFF"
}

fail() {
    bold "$@"
    exit 1
}

check_deps() {
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

    if test -n "$installer"; then
        for dep in "${BUILD_PKG_DEPS[@]}"; do
            if ! $have_dep "$dep" >/dev/null; then
                echo "You don't have the '$dep' package installed, you likely need to:"
                bold "    sudo $installer $dep"
                exit 1
            fi
        done
    fi
}

symlink_binary() {
    binary="$INST_DIR/bin/rtorrent"
    flavour="$1"
    test -z "$flavour" || ln -f "$binary" "$binary$flavour"

    mkdir -p "$BIN_DIR"
    ln -nfs "$binary$flavour" "$BIN_DIR/rtorrent-$RT_VERSION"
    test -e "$BIN_DIR/rtorrent" || ln -nfs rtorrent-$RT_VERSION "$BIN_DIR/rtorrent"
}


#
# RULES
#
prep() {
    # Create directories
    check_deps
    mkdir -p $INST_DIR/{bin,include,lib,man,share}
    mkdir -p tarballs
}

download() { # Download and unpack sources
    [[ -d tarballs ]] && [[ -f tarballs/DONE ]] && rm -f tarballs/DONE >/dev/null

    if $XMLRPC_SVN; then
        test -d xmlrpc-c-advanced-$XMLRPC_REV || ( echo "Getting xmlrpc-c r$XMLRPC_REV" && \
            svn -q checkout "$XMLRPC_URL" xmlrpc-c-advanced-$XMLRPC_REV )
    fi
    for url in "${TARBALLS[@]}"; do
        url_base=${url##*/}
        # skip downloading rtorrent and libtorrent here if git version should be used
        [ -z "${url_base##*rtorrent*}" ] && [ "$RT_VERSION" = "$RT_MAJOR.$GIT_MINOR" ] && continue
        [ -z "${url_base##*libtorrent*}" ] && [ "$RT_VERSION" = "$RT_MAJOR.$GIT_MINOR" ] && continue
        tarball_dir=${url_base%.tar.gz}
        tarball_dir=${tarball_dir%-src.tgz}
        test -f tarballs/${url_base} || ( echo "Getting $url_base" && command cd tarballs && curl -O $CURL_OPTS $url )
        test -d $tarball_dir || ( echo "Unpacking ${url_base}" && tar xfz tarballs/${url_base} )
        test -d $tarball_dir || fail "Tarball ${url_base} could not be unpacked"
    done

    if [ "$RT_VERSION" = "$RT_MAJOR.$GIT_MINOR" ]; then
        # getting rtorrent and libtorrent from GIT
        download_git_zip rakshasa rtorrent $GIT_RT
        download_git_zip rakshasa libtorrent $GIT_LT
        #bump_git_versions
    fi

    touch tarballs/DONE
}

download_git_zip() {
    owner="$1"; repo="$2"; repo_ver="$3";
    url="https://github.com/$owner/$repo/archive/$repo_ver.zip"
    test -f tarballs/$repo-$repo_ver.zip || ( echo "Getting $repo-$repo_ver.zip" && command cd tarballs && curl $CURL_OPTS -o $repo-$repo_ver.zip $url )
    test -d $repo-$repo_ver* || ( echo "Unpacking $repo-$repo_ver.zip" && unzip -oq tarballs/$repo-$repo_ver.zip )
    test -d $repo-$repo_ver* || fail "Zip $repo-$repo_ver.zip could not be unpacked"
    [ $repo == "rtorrent" ] && mv $repo-$repo_ver* $repo-$RT_VERSION || mv $repo-$repo_ver* $repo-$LT_VERSION
}

#bump_git_versions() {
#    # bump version number of rtorrent and libtorrent
#    $SED_I "s/rtorrent, .*, sundell/rtorrent, $RT_VERSION, sundell/" rtorrent-$RT_VERSION/configure.ac
#    # for RT_VERSION <= 0.9.6
#    $SED_I "s/libtorrent >= [^, ]*\([, ].*\)/libtorrent >= $LT_VERSION\1/g" rtorrent-$RT_VERSION/configure.ac
#    # for RT_VERSION >= 0.9.7
#    $SED_I "s/\[libtorrent >= .*\]/\[libtorrent >= $LT_VERSION\]/" rtorrent-$RT_VERSION/configure.ac
#    $SED_I "s/libtorrent, .*, sundell/libtorrent, $LT_VERSION, sundell/" libtorrent-$LT_VERSION/configure.ac
#}

automagic() {
    aclocal
    rm -f ltmain.sh scripts/{libtool,lt*}.m4
    $LIBTOOLIZE --automake --force --copy
    aclocal
    autoconf
    automake --add-missing
    ./autogen.sh
}

build_deps() {
    # Build direct dependencies
    test -e $SRC_DIR/tarballs/DONE || fail "You need to '$0 download' first!"

    ( cd c-ares-$CARES_VERSION && ./configure && $MAKE $MAKE_OPTS && $MAKE DESTDIR=$INST_DIR prefix= install )
    $SED_I s:/usr/local:$INST_DIR: $INST_DIR/lib/pkgconfig/*.pc $INST_DIR/lib/*.la
    ( cd curl-$CURL_VERSION && ./configure --enable-ares && $MAKE $MAKE_OPTS && $MAKE DESTDIR=$INST_DIR prefix= install )
    $SED_I s:/usr/local:$INST_DIR: $INST_DIR/lib/pkgconfig/*.pc $INST_DIR/lib/*.la
    ( cd xmlrpc-c-advanced-$XMLRPC_REV \
        && ./configure --prefix=$INST_DIR --with-libwww-ssl \
            --disable-wininet-client --disable-curl-client --disable-libwww-client --disable-abyss-server --disable-cgi-server \
        && $MAKE $MAKE_OPTS && $MAKE install )
    $SED_I s:/usr/local:$INST_DIR: $INST_DIR/bin/xmlrpc-c-config
    touch $INST_DIR/lib/DEPS-DONE
}

core_unpack() { # Unpack original LT/RT source
    test -e $INST_DIR/lib/DEPS-DONE || fail "You need to '$0 build' first!"

    if [ "$RT_VERSION" = "$RT_MAJOR.$GIT_MINOR" ]; then
        unzip -oq tarballs/libtorrent-$GIT_LT.zip
        [ -d libtorrent-$GIT_LT* ] && cp -rfT libtorrent-$GIT_LT* libtorrent-$LT_VERSION/ && rm -rf libtorrent-$GIT_LT*
        unzip -oq tarballs/rtorrent-$GIT_RT.zip
        [ -d rtorrent-$GIT_RT* ] && cp -rfT rtorrent-$GIT_RT* rtorrent-$RT_VERSION/ && rm -rf rtorrent-$GIT_RT*
        #bump_git_versions
    else
        tar xfz tarballs/libtorrent-$LT_VERSION.tar.gz
        tar xfz tarballs/rtorrent-$RT_VERSION.tar.gz
    fi
}

build() { # Build and install all components
    bold "~~~~~~~~~~~~~~~~~~~~~~~~   Building libTorrent   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

    ( set +x ; [[ -n "$FIX_LT_GCC_BUG" ]] &&  unset CXXFLAGS ; \
        cd libtorrent-$LT_VERSION && automagic && \
        ./configure $CFG_OPTS $CFG_OPTS_LT && \
        $MAKE clean && $MAKE $MAKE_OPTS && $MAKE DESTDIR=$INST_DIR prefix= install )
    $SED_I s:/usr/local:$INST_DIR: $INST_DIR/lib/pkgconfig/*.pc $INST_DIR/lib/*.la

    bold "~~~~~~~~~~~~~~~~~~~~~~~~   Building rTorrent   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

    ( set +x ; [[ -n "$FIX_LT_GCC_BUG" ]] &&  unset CXXFLAGS ; \
        cd rtorrent-$RT_VERSION && automagic && \
        ./configure $CFG_OPTS $CFG_OPTS_RT --with-xmlrpc-c=$INST_DIR/bin/xmlrpc-c-config && \
        $MAKE clean && $MAKE $MAKE_OPTS && $MAKE DESTDIR=$INST_DIR prefix= install )
}

extend() { # Rebuild and install libtorrent and rTorrent with patches applied
    ${NOBUILD:-false} || core_unpack

    # Version handling
    RT_HEX_VERSION=$(printf "0x%02X%02X%02X" ${RT_VERSION//./ })
    $SED_I "s:\\(AC_DEFINE(HAVE_CONFIG_H.*\\):\1  AC_DEFINE(RT_HEX_VERSION, $RT_HEX_VERSION, for CPP if checks):" rtorrent-$RT_VERSION/configure.ac
    grep "AC_DEFINE.*API_VERSION" rtorrent-$RT_VERSION/configure.ac >/dev/null || \
        $SED_I "s:\\(AC_DEFINE(HAVE_CONFIG_H.*\\):\1  AC_DEFINE(API_VERSION, 0, api version):" rtorrent-$RT_VERSION/configure.ac

    # Patch libtorrent
    pushd libtorrent-$LT_VERSION

    for corepatch in $SRC_DIR/patches/lt-ps_{*${LT_VERSION%-svn}*,all}_*.patch; do
        test ! -e "$corepatch" || { bold "$(basename $corepatch)"; patch -uNp0 -i "$corepatch"; }
    done

    for backport in $SRC_DIR/patches/{backport,misc}_{*${LT_VERSION%-svn}*,all}_*.patch; do
        test ! -e "$backport" || { bold "$(basename $backport)"; patch -uNp0 -i "$backport"; }
    done

    popd
    bold "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

    # Patch rTorrent
    pushd rtorrent-$RT_VERSION

    for corepatch in $SRC_DIR/patches/ps-*_{*${RT_VERSION%-svn}*,all}.patch; do
        test ! -e "$corepatch" || { bold "$(basename $corepatch)"; patch -uNp1 -i "$corepatch"; }
    done

    for backport in $SRC_DIR/patches/{backport,misc}_*${RT_VERSION%-svn}*_*.patch; do
        test ! -e "$backport" || { bold "$(basename $backport)"; patch -uNp0 -i "$backport"; }
    done

    ${NOPYROP:-false} || for pyropatch in $SRC_DIR/patches/pyroscope_{*${RT_VERSION%-svn}*,all}.patch; do
        test ! -e "$pyropatch" || { bold "$(basename $pyropatch)"; patch -uNp1 -i "$pyropatch"; }
    done

    ${NOPYROP:-false} || for i in "$SRC_DIR"/patches/*.{cc,h}; do
        ln -nfs $i src
    done

    ${NOPYROP:-false} || for uipyropatch in $SRC_DIR/patches/ui_pyroscope_{*${RT_VERSION%-svn}*,all}.patch; do
            test ! -e "$uipyropatch" || { bold "$(basename $uipyropatch)"; patch -uNp1 -i "$uipyropatch"; }
    done

    ${NOPYROP:-false} || $SED_I "s%rTorrent \\\" VERSION \\\"/\\\"%rTorrent-PS-CH $RT_CH_VERSION $RT_VERSION/$LT_VERSION - \\\"%" src/ui/download_list.cc
    ${NOPYROP:-false} || $SED_I "s%std::string(torrent::version()) + \\\" - \\\" +%%" src/ui/download_list.cc
    popd
    bold "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

    # Build it (note that libtorrent patches ALSO influence the "vanilla" version)
    ${NOBUILD:-false} || build

    # Remove unnecessary files
    ${NOBUILD:-false} || rm -rf "$INST_DIR/"{lib/*.a,lib/*.la,lib/pkgconfig,share/man,man,share,include,bin/curl,bin/*-config}
}

clean() { # Clean up generated files
    for i in $SUBDIRS; do
        ( cd $i && $MAKE clean )
    done
}

clean_all() { # Remove all downloads and created files
    test ! -d tarballs || rm -f tarballs/*{.tar.gz,.tgz} tarballs/DONE tarballs/*.zip >/dev/null || :
    for i in $SUBDIRS; do
        test ! -d $i || rm -rf $i >/dev/null
    done
}

check() { # Print some diagnostic success indicators
    for i in "$BIN_DIR"/rtorrent{,-$RT_VERSION}; do
        echo $i "->" $(readlink $i) | sed -e "s:$HOME:~:g"
    done

    # This first selects the rpath dependencies, and then filters out libs found in the install dirs.
    # If anything is left, we have an external dependency that sneaked in.
    echo
    echo -n "Check that static linking worked: "
    libs=$(ldd "$BIN_DIR"/rtorrent-$RT_VERSION | egrep "lib(cares|curl|xmlrpc|torrent)")		#"
    if test "$(echo "$libs" | egrep -v "$INST_DIR" | wc -l)" -eq 0; then
        echo OK; echo
    else
        echo FAIL; echo; echo "Suspicious library paths are:"
        echo "$libs" | egrep -v "$INST_DIR" || :
        echo
    fi
    echo "Dependency library paths:"
    echo "$libs" | sed -e "s:$HOME:~:g"
}

install() { # Install to $PKG_INST_DIR
    export INST_DIR="$PKG_INST_DIR"
    test -d "$INST_DIR"/. || mkdir -p "$INST_DIR"/
    rm -rf "$INST_DIR"/* || :
    test "$(echo $INST_DIR/*)" = "$INST_DIR/*" || fail "Could not clean install dir '$INST_DIR'"
    cat >"$INST_DIR"/version-info.sh <<.
RT_CH_VERSION=$RT_CH_VERSION
RT_PS_VERSION=$RT_VERSION
RT_PS_REVISION=$(date +'%Y%m%d')-$(git rev-parse --short HEAD)
RT_PS_LT_VERSION=$LT_VERSION
RT_PS_CARES_VERSION=$CARES_VERSION
RT_PS_CURL_VERSION=$CURL_VERSION
RT_PS_XMLRPC_REV=$XMLRPC_REV
.
    clean_all; prep; download;
    set_build_env; build_deps; extend
    #check
    ln -nfs "$INST_DIR" "$ROOT_SYMLINK_DIR"
}

package_prep() { # make $PACKAGE_ROOT lean and mean
    test -n "$DEBFULLNAME" || fail "You MUST set DEBFULLNAME in your environment"
    test -n "$DEBEMAIL" || fail "You MUST set DEBEMAIL in your environment"

    DIST_DIR="/tmp/rt-ps-dist"
    rm -rf "$DIST_DIR" && mkdir -p "$DIST_DIR"
    chmod -R a+rX "$PKG_INST_DIR/"

    . "$PKG_INST_DIR"/version-info.sh
}

call_fpm() {
    fpm -s dir -n "${fpm_pkg_name:-rtorrent-ps-ch}" \
        -v "$RT_CH_VERSION-$RT_PS_VERSION" --iteration "$fpm_iteration" \
        -m "\"$DEBFULLNAME\" <$DEBEMAIL>" \
        --license "$fpm_license" --vendor "https://github.com/rakshasa , https://github.com/pyroscope/rtorrent-ps#rtorrent-ps" \
        --description "Patched and extended ncurses BitTorrent client" \
        --url "https://github.com/chros73/rtorrent-ps#rtorrent-ps" \
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
    deps=$(ldd "$PKG_INST_DIR"/bin/rtorrent | cut -f2 -d'>' | cut -f2 -d' ' | egrep '^/lib/|^/usr/lib/' \
        | xargs -i+ dpkg -S "+" | cut -f1 -d: | sort -u | xargs -i+ echo -d "+")

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

build_everything() {
    # Go through all build steps
    set_build_env
    ${NODEPS:-false} || build_deps
    build
    symlink_binary -vanilla
    check
}


#
# MAIN
#
cd "$SRC_DIR"
case "$1" in
    all)        prep; download; build_everything ;;
    clean)      clean ;;
    clean_all)  clean_all ;;
    download)   prep; download ;;
    env)        prep; set +x; set_build_env echo '"';;
    build)      prep; build_everything ;;
    rtorrent)   prep; core_unpack; NODEPS=true; build_everything ;;
    extend)     prep
                set_build_env
                test -e "$SRC_DIR/rtorrent-$RT_VERSION/src/rtorrent" || fail "You need to '$0 all' first!"
                extend
                symlink_binary -extended
                check
                ;;
    ps|extend-only)
                clean_all
                prep
                download
                set_build_env
                build_deps;
                extend
                symlink_binary -extended
                check
                ;;
    patch)      NOBUILD=true; extend ;;
    patch-dev)  NOPYROP=true; NOBUILD=true; extend ;;
#    down)       clean_all; prep; download; core_unpack ;;
    check)      check ;;
    install)    install;;
    pkg2deb)    pkg2deb;;
    pkg2pacman) pkg2pacman;;
    *)
        echo >&2 "${BOLD}Usage: $0 (all [git] | clean | clean_all | download [git] | build | check [git] | extend [git] | ps [git] | install [git] | pkg2deb [git] | pkg2pacman [git])$OFF"
        echo >&2 "Build rTorrent $RT_VERSION/$LT_VERSION into $(sed -e s:$HOME/:~/: <<<$INST_DIR)"
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
        grep "() { #" $0 | grep -v grep | sort | sed -e "s:^:  :" -e "s:() { #:  @:" | while read i; do
            echo "   " $(eval "echo $i") | tr @ \\t
        done
        exit 1
        ;;
esac
