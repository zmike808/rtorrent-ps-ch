#! /usr/bin/env bash
#
# Run an EMPHEMERAL rTorrent-PS instance in a Stretch container, like this:
#
#   git clone "https://github.com/pyroscope/rtorrent-ps.git" ~/src/rtorrent-ps
#   ~/src/rtorrent-ps/docker/launch-on-stretch.sh
#
# Incidentally, this is also a condensed version of…
#
#   https://github.com/pyroscope/rtorrent-ps/blob/master/docs/DebianInstallFromSource.md
#
# Detach from the process using ``Ctrl-P Ctrl-Q``,
# and call ``reset`` to reset your terminal.
#
# Reattach with ``docker attach rt-ps-demo``,
# then enter ``Ctrl-A r`` to refresh the ``tmux`` screen.
#

set -e

# Both Stretch and Bionic have problems with the current v1.1 column headers
#distro="debian:stretch"
distro="ubuntu:bionic"
#distro="ubuntu:xenial"
rtps_version="0.9.6-PS-1.1-25-g1b53ac9~${distro#*:}"

ALREADY_IN_TMUX=${2:-0}

case "$1" in
as-root)
    # Install basics
    apt update -qq
    apt-get install -y apt-transport-https lsb-release locales \
        lsof binutils less vim git tmux curl wget libcppunit-dev \
        python-setuptools python-virtualenv python-dev
    echo "en_US.UTF-8 UTF-8" >/etc/locale.gen
    locale-gen

    # Install rT-PS
    echo >/etc/apt/sources.list.d/rtps.list \
         "deb [trusted=yes] https://dl.bintray.com/pyroscope/rtorrent-ps /"
    apt update -qq
    apt install -y rtorrent-ps=$rtps_version
    ln -s /opt/rtorrent/bin/rtorrent /usr/local/bin
    rtorrent -h | head -n1

    # Create rtorrent user, and become rtorrent
    groupadd rtorrent
    useradd -g rtorrent -G rtorrent,users -c "rTorrent client" -s /bin/bash --create-home rtorrent
    chmod 750 ~rtorrent
    su - rtorrent -c "mkdir -p ~/bin"
    su - rtorrent -c "bash $0 as-rtorrent $ALREADY_IN_TMUX"
    ;;

as-rtorrent)
    # Install pyrocore
    mkdir -p ~/bin ~/.local
    git clone "https://github.com/pyroscope/pyrocore.git" ~/.local/pyroscope
    $_/update-to-head.sh
    ~/bin/pyroadmin --version

    # Create rtorrent instance
    export RT_HOME="${RT_HOME:-$HOME/rtorrent}"
    mkdir -p $RT_HOME; cd $RT_HOME
    mkdir -p .session log work done watch/{start,load,hdtv}
    cp ~/.local/pyroscope/docs/examples/start.sh ./start
    chmod a+x ./start
    ~/.local/pyroscope/src/scripts/make-rtorrent-config.sh
    sed -i -re 's/(method.*pyro.extended.*)0/\11/' ~/rtorrent/rtorrent.rc
    echo >>~/rtorrent/rtorrent.d/.rcignore "disable-control-q.rc"

    # Create pyrocore config
    pyroadmin --create-config
    cat >~/.pyroscope/config.ini <<EOF
# PyroScope configuration file
#
# For details, see https://pyrocore.readthedocs.org/en/latest/setup.html
#

[GLOBAL]
# Location of your rtorrent configuration
rtorrent_rc = ~/rtorrent/rtorrent.rc
scgi_url = scgi://$HOME/rtorrent/.scgi_local

[ANNOUNCE]
# Add alias names for announce URLs to this section; those aliases are used
# at many places, e.g. by the "mktor" tool and to shorten URLs to these aliases
EOF
    mktor -o ~/rtorrent/watch/load ~/rtorrent/start http://example.com
    sed -i -re 's/122,/  5,/' ~/rtorrent/rtorrent.d/watch-dirs.rc

    # Start tmux session
    cp --no-clobber ~/.local/pyroscope/docs/examples/tmux.conf ~/.tmux.conf
    if test "$ALREADY_IN_TMUX" = 1; then
        ~/rtorrent/start
    else
        tmux -2u new -n rT-PS -s rtorrent "~/rtorrent/start; exec bash"
        while true; do sleep 1; tmux -2u attach -t rtorrent || break; done
    fi
    ;;

*)
    test -z "$TMUX"; ALREADY_IN_TMUX=$?
    docker rm rt-ps-demo >/dev/null 2>&1 || :
    docker run -it -v $(command cd $(dirname "$0") >/dev/null && pwd):/srv \
               --name rt-ps-demo "$@" ${distro} \
               bash "/srv/$(basename $0)" as-root $ALREADY_IN_TMUX
    ;;
esac
