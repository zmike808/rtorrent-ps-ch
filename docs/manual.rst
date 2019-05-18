User's Manual
=============

This chapter describes the additional features in *rTorrent-PS*,
and other differences to a vanilla *rTorrent* build.


.. _features-std-cfg:

Additional Features
-------------------

Using the right default configuration (more on that below),
you will get the following additional features in your `rTorrent-PS` installation:

#.  The ``t`` key is bound to a ``trackers`` view that shows all items
    sorted by tracker and then by name.
#.  The ``!`` key is bound to a ``messages`` view, listing all items
    that currently have a non-empty message, sorted in order of the
    message text.
#.  The ``^`` key is bound to the ``rtcontrol`` search result view, so
    you can easily return to your last search.
#.  The ``?`` key is bound to the ``indemand`` view, which sorts all
    open items by their activity, with the most recently active on top.
#.  The ``%`` key is bound to the ``ratio`` view, which sorts all
    open items by their ratio (descending).
#.  The ``°`` key is bound to the ``uploaded`` view, which sorts all
    open items by their total upload amount (descending).
#.  The ``"`` key is bound to the ``datasize`` view, which sorts all
    open items by the size of their content data (descending).
#.  Add even more views, see :ref:`additional-views` for details.
#.  ``Page ↑`` and ``Page ↓`` scroll by 50 items at a time (or whatever
    other value ``ui.focus.page_size`` has).
#.  ``Home`` / ``End`` jump to the first / last item in the current
    view.
#.  :kbd:`Ctrl-F` opens a prompt where you can enter a search term,
    and :kbd:`Shift-F` or :kbd:`F3` jump to the next hit for that term.
    If nothing matches, a message is shown on the console.
    |rt-ps-ui-find|
#.  The ``~`` key rotates through all available color themes, or a
    user-selected subset. See :ref:`color-themes` for details.
#.  The ``<`` and ``>`` keys rotate through all added category views
    (``pyro.category.add=‹name›``), with filtering based on the
    ruTorrent label (``custom_1=‹name›``). See :ref:`category-views` for details.
#.  ``|`` reapplies the category filter and thus updates the current
    category view.
#.  The ``u`` key shows the uptime and some other essential data of your
    rTorrent instance.
#.  ``F2`` shows some important help resources (web links) in the
    console log.
#.  ``*`` toggles between the collapsed (as described on `Extended
    Canvas Explained`_) and the expanded display of the current view.
    |rt-ps-canvas-v2-small|
#.  ``/`` toggles the visibility of ‘sacrificial’ columns – normally,
    they're only hidden when the terminal width gets too small.
#.  The ``active`` view is changed to include all incomplete items
    regardless of whether they have any traffic, and then groups the
    list into complete, incomplete, and queued items, in that order.
    Within each group, they're sorted by download and then upload speed.
#.  Some `canvas v2` columns are added in the `pimp-my-box` configuration –
    the selected throttle (⋉), a download's chunk size (≣),
    and the expected time of arrival (⟲ ◥◤) on the *active* and *leeching* displays only.
    The visibility of the chunk size column can be toggled using the ``_`` key.
#.  The commands ``s=«keyword»``, ``t=«tracker_alias»``, and
    ``f=«filter_condition»`` are pre-defined for searching using a
    Ctrl-X prompt.
#.  The ``.`` key toggles the membership in the ``tagged`` view for the
    item in focus, ``:`` shows the ``tagged`` view, and ``T`` clears
    that view (i.e. removes the tagged state on all items). This can be
    very useful to manually select a few items and then run
    ``rtcontrol`` on them, or alternatively use ``--to-view tagged`` to
    populate the ``tagged`` view, then deselect some items interactively
    with the ``.`` key, and finally mass-control the rest.
    See :ref:`additional-views` for details.
#.  You can use the ``purge=`` and ``cull=`` commands (on a Ctrl-X
    prompt) for deleting the current item and its (incomplete) data.
#.  ``Ctrl-g`` shows the tags of an item (as managed by ``rtcontrol``);
    ``tag.add=‹tag›`` and ``tag.rm=‹tag›`` can be used to change the set
    of tags, both also show the new set of tags after changing them.
#.  Time-stamped log files with rotation, archival (compression), and pruning
    – with a setting for the number of days to keep logs in uncompressed form, or at all.
#.  Trackers are scraped regularly (active items relatively often,
    inactive items including closed ones seldomly), so that the display
    of downloads / seeders / leechers is not totally outdated.
    The ``&`` key can be used to manually scrape the item in focus.
#.  A watchdog for the ``pyrotorque`` daemon process (checks every 5 minutes,
    and starts it when not running *if* the `~/.pyroscope/run/pyrotorque` file exists).

With regards to using the ‘right’ configuration to get the above, you need
the ``*.rc.default`` files in the ``~/.pyroscope/rtorrent.d`` directory
provided by `pyrocore`.
:ref:`std-config` has details on these.
Some more features are defined by the `pimp-my-box`_ configuration templates.

To get there, perform the :ref:`DebianInstallFromSource` as described in this manual,
or use the `pimp-my-box`_ project for an automatic remote installation.
The instructions in the :ref:`rtorrent-pyro-rc` section of the `pyrocore` manual
only cover half of it, and you might miss some described features.


.. |rt-ps-ui-find| image:: _static/img/rt-ps-ui-find.png

.. |rt-ps-canvas-v2-small| image:: _static/img/rT-PS-1.0-301-g573a782-2018-06-10-small.png


.. _extended-canvas:

Extended Canvas Explained
-------------------------

The following is an explanation of the collapsed display of `rTorrent-PS` (*canvas v2*).

.. figure:: _static/img/rT-PS-1.0-301-g573a782-2018-06-10-shadow.png
   :align: center
   :alt: Extended Canvas Screenshot

   Extended Canvas Screenshot

In case your screen looks broken compared to this,
see :ref:`terminal-setup` for necessary pre-conditions and settings
regarding your terminal emulator application and operating system.

In older builds, you need to remember to press the ``*`` key while showing a view,
or change the state of new views after adding them (by calling the `view.collapsed.toggle`_ command),
else you won't ever see it.

The following is an overview of the default columns, and what the values and icons in them mean.

A ``⍰`` after the column title indicates a ‘sacrificial’ column, which disappear when the display
gets too narrow to display all the columns. When even that does not provide enough space,
columns are omitted beginning on the right side (*Name* is always included).
Sacrificial columns can also be toggled using the ``/`` key
– note they're toggled as a whole group,
so other dynamic states like the ``≣`` column toggle are ignored.

Columns marked ``⪮`` are provided by a `pimp-my-box`_ configuration include
(i.e. loaded from ``~/rtorrent/rtorrent.d/``),
and ones carrying ``✶`` by ``pyrocore`` (from ``~/.pyroscope/rtorrent.d/``).
All others are built-in.


❢
    Message or alert indicator (♺ = Tracker cycle complete,
    i.e. "Tried all trackers"; ʘ = item's data path does not exist
    (needs `support by a cron job`_); ⚡ = establishing connection;
    ↯ = data transfer problem; ◔ = timeout; ¿? = unknown torrent /
    info hash; ⨂ = authorization problem (possibly temporary); ⋫ = tracker
    downtime; ☡ = DNS problems; ⚠ = other)
☢
    Item state (▹ = started, ╍ = paused, ▪ = stopped)
☍    ``⍰``
    Tied item? [⚯]
⌘    ``⍰``
    Command lock-out? (⚒ = heed commands, ◌ = ignore commands)
↺   ``⍰``
    Number of completions from last scrape info
⤴     ``⍰``
    Number of seeds from last scrape info
⤵     ``⍰``
    Number of leeches from last scrape info
↕   ``⍰``
    Transfer direction indicator [⇅ ↡ ↟]
℞
    Number of connected peers
∆⋮ ⟲
    Upload rate, or when inactive, time the download took (only after completion).
∇⋮ ◷
    Approximate time since completion (units are «”’hdwmy» from seconds to years);
    for incomplete items the download rate or, if there's no traffic,
    the time since the item was started or loaded
⟲ ◥◤ ``⍰ ⪮``
    Expected time of arrival (only on the *active* and *leeching* views)
⋉   ``⍰ ⪮``
    Throttle selected for this item (∞ is the special ``NULL`` throttle; ⓪…⑨ for
    `ruTorrent`'s ``thr_0…9`` channels)
Σ⇈  ``⍰``
    Total sum of uploaded data
⣿
    Completion status (✔ = done; else up to 8 dots [⣿] and ❚, i.e. progress in 10% steps);
    the old ``ui.style.progress.set`` command is deprecated,
    see :ref:`add-custom-columns` for the new way to get
    a different set of glyphs or an ASCII version
☯
    Ratio (☹ plus color indication for < 1, ➀ — ➉ : >= the number, ⊛ : >= 11);
    the old ``ui.style.ratio.set`` command is deprecated,
    see :ref:`add-custom-columns` for the new way to get
    a different set of number glyphs or an ASCII version
☯ ‰ ``⍰ ✶``
    Detailed ratio, in promille and as a number (only on the *ratio* view).
⛁
    Data size
≣   ``⍰ ⪮``
    Chunk size – this column can be toggled on / off using the ``_`` key
◷ ↑↓ ``✶``
    Time of last data transfer (only on the *last_xfer* view).
◷ ↺⤴⤵ ``✶``
    Time of last tracker scrape (only on the *trackers* view).
Domain ``⍰ ✶``
    15 characters of the unmapped tracker domain name (only on the *trackers* view).
◷ ℞ ``✶``
    Time a peer was last connected, or the number of peers connected right now (only on the *indemand* view).
✰
    Priority (✖ = off, ⇣ = low, nothing for normal, ⇡ = high)
⚑
    A ⚑ indicates this item is on the ``tagged`` view
Name
    Name of the download item – either the name contained in the metafile,
    or else the value of the ``displayname`` custom field when set on an item
Tracker
    Domain of the first HTTP tracker with seeds or leeches,
    or else the first one altogether – note that you can define nicer
    aliases using the `trackers.alias.set_key`_ command in your configuration


For the various time displays to work, you need
the `pyrocore` :ref:`standard configuration for rtorrent.rc <rtorrent-pyro-rc>`.

The scrape info and peer numbers are exact only for values below 100, else they
indicate the order of magnitude using roman numerals (c = 10², m = 10³,
X = 10⁴, C = 10⁵, M = 10⁶).
For up-to-date scrape info, you need the `Tracker Auto-Scraping`_ configuration from `pyrocore`.

.. _`Tracker Auto-Scraping`: https://github.com/pyroscope/pyrocore/blob/master/src/pyrocore/data/config/rtorrent.d/auto-scrape.rc#L1
.. _`support by a cron job`: https://github.com/pyroscope/pimp-my-box/commit/ee96e5074412e3e010bf6cf1906639634b081cce#diff-28aed99001b37b5d394978a621f41987


.. _commands:

Command Extensions
------------------

The following new commands are available.
Note that the links point to the `Commands Reference`_ chapter in the *rTorrent Handbook*.

.. include:: include-commands.rst

.. _`Commands Reference`: https://rtorrent-docs.readthedocs.io/en/latest/cmd-ref.html


.. _Bintray: https://bintray.com/pkg/show/general/pyroscope/rtorrent-ps/rtorrent-ps
.. _installation options: https://github.com/pyroscope/rtorrent-ps#installation
.. _Arch Linux: http://www.archlinux.org/
.. _`pimp-my-box`: https://github.com/pyroscope/pimp-my-box/

.. end of "manual.rst"
