Debian Install From Source - The Easy Way
=========================================

.. contents:: **Contents**


Introduction
------------

This guide will show only the required methods / commands to get ``rTorrent-PS-CH`` and ``pyrocore`` utilities up and running in ``tmux``. It's really easy with the help of the amazing build scripts created by ``pyroscope``.

Note that ``rTorrent-PS-CH`` can be "installed" in 2 ways but if you have ``root`` access then the `system wide <#system-wide>`_ way is the preferred one.

If you have any problem you can still refer to the `old instructions <DebianInstallFromSource.md>`_.



Installing build dependencies
-----------------------------

First, you need to install a few **required** packages — **and no, this is not optional in any way**. They require about ``250 MB`` disk space. These steps must be performed by the ``root`` user (i.e. in a root shell, or by writing ``sudo`` before the actual command):

.. code-block::

   apt-get update
   apt-get install tmux wget build-essential subversion git unzip pkg-config \
       libssl-dev libncurses5-dev libncursesw5-dev locales libcppunit-dev zlib1g-dev \
       autoconf automake libtool libxml2-dev libxslt1-dev curl ruby ruby-dev mc \
       python python-dev python-virtualenv python-pip python-setuptools python-pkg-resources
   gem install fpm


Note about ``tmux``
^^^^^^^^^^^^^^^^^^^

After that all you need is to place a `.tmux.conf <https://raw.githubusercontent.com/chros73/rtorrent-ps_setup/master/ubuntu-14.04/home/chros73/.tmux.conf>`_ like that in your home directory (can be ``root`` or a regular user) and you can already run ``tmux``: 

.. code-block::

   cd ~; wget https://raw.githubusercontent.com/chros73/rtorrent-ps_setup/master/ubuntu-14.04/home/chros73/.tmux.conf
   tmux

There is only 1 crucial option (along with the other useful ones) in that ``.tmux.conf``: ``set -g default-terminal "screen-256color"``. This is responsible for getting 256 color support. **No matter** what other tutorials / guides / intructions (like old docs in the ``docs`` directory ) say about the ``TERM`` environment variable: **you shouldn't set it**! You will experience strange rendering problems! Although this will result that ``rTorrent-PS-CH`` won't start in a terminal window, but that's not a problem since we always run it in ``tmux``. (`Read more <https://sanctum.geek.nz/arabesque/term-strings/>`_ about it.)



Compiling ``rTorrent-PS-CH`` from source
-----------------------------------

Multiple versions can be supported or just the latest stable ``git`` version. If patches for multiple version can be found inside the ``patches`` directory then ``build.sh`` will compile the latest release version, in this case ``git`` option can be passed to it to build ``git`` version.
If ``ONLYSUPPORTGITVERSION`` is set to true in ``build.sh`` script then it will always build ``git`` version.

System wide
^^^^^^^^^^^

You need ``root access`` for this and this is the ``preferred way`` if you have root access.

It will build ``rTorrent-PS-CH`` binary including some libraries into ``/opt/rtorrent-*`` directory and create ``/opt/rtorrent`` symlink for it.

.. code-block::

   mkdir -p ~/src/; cd ~/src/
   git clone https://github.com/chros73/rtorrent-ps.git
   cd rtorrent-ps
   ./build.sh clean_all
   nice -n 19 time ./build.sh install

The only thing you need to do after this is to ``symlink`` the executable into main path (so we can start it with ``rtorrent`` command later):

.. code-block::

   ln -s /opt/rtorrent/bin/rtorrent /usr/local/bin


Creating deb package
""""""""""""""""""""

You can even ``create a package`` of this build with ``fpm`` if you like (so you can distribute it later):

.. code-block::

   export DEBFULLNAME="yourname"; export DEBEMAIL="youremailaddress"
   ./build.sh pkg2deb

You should copy resulted ``*.deb`` package from ``/tmp/rt-ps-dist`` to somewhere safe.


Creating Arch Linux package
"""""""""""""""""""""""""""

You can even ``create a package`` of this build with ``pacman`` (``fpm`` from the AUR should be used!) if you like (so you can distribute it later):

.. code-block::

   export DEBFULLNAME="yourname"; export DEBEMAIL="youremailaddress"
   ./build.sh pkg2pacman

You should copy resulted ``*.tar.xz`` package from ``/tmp/rt-ps-dist`` to somewhere safe.



For regular user
^^^^^^^^^^^^^^^^

It can be useful if you don't have root access or you want to patch the client.

It will build ``rTorrent-PS-CH`` binary including some libraries into ``~/lib/rtorrent-*`` directory and create symlink to it in ``./bin/`` directory.

.. code-block::

   mkdir -p ~/src/; cd ~/src/
   git clone https://github.com/chros73/rtorrent-ps.git
   cd rtorrent-ps
   ./build.sh clean_all
   nice -n 19 time ./build.sh ps


If all went well
^^^^^^^^^^^^^^^^

Check the result by running ``rtorrent`` (you don't need a config file for this) in a ``tmux`` window, not terminal window!

You can delete the ``~/src/rtorrent-ps/`` directory later in both above cases if all went well with:

.. code-block::

   cd ~ && [ -d ~/src/rtorrent-ps/ ] && rm -rf ~/src/rtorrent-ps/



Install ``pyrocore`` utils for regular user
-------------------------------------------

You should run these under your normal user account:

.. code-block::

   mkdir -p ~/bin ~/lib
   git clone "https://github.com/pyroscope/pyrocore.git" ~/lib/pyroscope
   cd ~ && ~/lib/pyroscope/update-to-head.sh

You can check whether all went well with:

.. code-block::

   pyroadmin --version

If you want to update ``pyrocore`` utils later:

.. code-block::

   cd ~/lib && tar -czf pyroscope-$(date +'%Y-%m-%d').tar.gz pyroscope    # make backup first
   cd ~ && ./lib/pyroscope/update-to-head.sh                              # update it
   pyroadmin --version                                                    # check for success


Summary
-------

It's really that simple, it only took about 30 minutes.

