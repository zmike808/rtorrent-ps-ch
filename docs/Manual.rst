User's Manual
=============

Extended Canvas Explained
-------------------------

Columns in the Collapsed Display
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The following is an explanation of the collapsed display of
*rTorrent-PS-CH* — remember that you need to bind a key (``*`` by default) to the
``view.collapsed.toggle`` command, else you won't ever see it.

.. figure:: _static/img/rTorrent-PS-CH-0.9.6-solarized-yellow-kitty-s.png
   :align: center
   :alt: rTorrent-PS Main View

   *rTorrent-PS-CH collapsed canvas*

The following is an overview of the column heading icons, their corresponding key definitions and what the values and icons in it mean.

.. |_| unicode:: 0xA0
   :trim:

==============  ====================================  ===========
 Column          Key                                  Description
==============  ====================================  ===========
 ☢              "100:1:☢"                             Item state (▹ = started, ╍ = paused, ▪ = stopped)
 ☍              "110:1:☍"                             Tied item? [⚯]
 ⌘              "120:1:⌘"                             Command lock-out? (⚒ = heed commands, ◌ = ignore commands)
 ✰              "130:1:✰"                             Priority (✖ = off, ⇣ = low, nothing for normal, ⇡ = high)
 ⊘              "200:1:⊘"                             Throttle (none = global throttle, ∞ = NULL throttle, otherwise the first letter of the throttle name)
 ⣿              "300:2:⣿ "                            Completion status (✔ = done; else up to 8 dots [⣿], i.e. 9 levels of 11% each); change to bar style using ``ui.style.progress.set=2``, ``0`` is a _mostly_ ASCII one
 ⋮              "310:1:⋮"                             Transfer direction indicator [⇅ ↡ ↟]
 ☯              "320:2:☯ "                            Ratio (☹  plus color indication for < 1, ➀  — ➉ : >= the number, ⊛ : >= 11); change to a different set of number glyphs using ``ui.style.ratio.set=2`` (or ``3``), ``0`` is a _mostly_ ASCII one
 ⚑              "330:2:⚑ "                            Message (♺ = Tracker cycle complete, i.e. "Tried all trackers"; ⚡ = establishing connection; ↯ = data transfer problem; ◔ = timeout; ¿? = unknown torrent / info hash; ⨂ = authorization problem (possibly temporary); ⚠ = other; ⚑ = on the ``tagged`` view)
 ↺              "400:2: ↺"                            Number of completions from last scrape info
 ⤴              "410:2: ⤴"                            Number of seeds from last scrape info
 ⤵              "420:2: ⤵"                            Number of leeches from last scrape info
 ↻              "430:2: ↻"                            Number of connected peers
 ⌬ ≀∆           "600:5: |_| ⌬ |_| ≀∆"                  Approximate time since last active state (units are «”’hdwmy» from seconds to years) or upload rate
 ⊼              "700:6: |_| |_| |_| ⊼ |_| |_|"        Uploaded data size
 ⌬ ≀∇           "800:5: |_| ⌬ |_| ≀∇"                 Approximate time since completion (units are «”’hdwmy» from seconds to years); for incomplete items the download rate or, if there's no traffic, the time since the item was loaded
 ✇              "900:4: |_| |_| ✇ |_|"                Data size
 Name                                                 Name of the download item
Tracker Domain                                        Domain of the first HTTP tracker with seeds or leeches, or else the first one altogether
==============  ====================================  ===========

The scrape info numbers are exact only for values below 100, else they
indicate the order of magnitude using roman numerals (c = 10², m = 10³,
X = 10⁴, C = 10⁵, M = 10⁶).

For example, to add back the removed two "Unsafe data" and "Data directory" columns, add these lines into your config:

.. code-block:: ini

    # Add Unsafe data column (◎)
    method.set_key = ui.column.render, "230:1:◎", ((string.map, ((cat, ((d.custom,unsafe_data)))), {0, " "}, {1, "⊘"}, {2, "⊗"}))
    # Add Data directory column (⊕) (first character of parent directory)
    method.set_key = ui.column.render, "250:1:⊕", ((d.parent_dir))

The result:

==============  ====================================  ===========
 Column          Key                                  Description
==============  ====================================  ===========
 ◎              "230:1:◎"                             Unsafe-data (none = safe data, ⊘ = unsafe data, ⊗ = unsafe data with delqueue)
 ⊕              "250:1:⊕"                             Data directory (none = base path entry is missing, otherwise the first letter of the name of data directory)
==============  ====================================  ===========



Adding Traffic Graphs
^^^^^^^^^^^^^^^^^^^^^

Add these lines to your configuration:

.. code-block:: ini

    # Show traffic of the last hour
    network.history.depth.set = 112
    schedule = network_history_sampling,1,32, network.history.sample=
    method.insert = network.history.auto_scale.toggle, simple|private, \
        "branch=network.history.auto_scale=, \
            \"network.history.auto_scale.set=0\", \
            \"network.history.auto_scale.set=1\""
    method.insert = network.history.auto_scale.ui_toggle, simple|private, \
        "network.history.auto_scale.toggle= ;network.history.refresh="
    branch=pyro.extended=,"schedule = bind_auto_scale,0,0, \
        \"ui.bind_key=download_list,=,network.history.auto_scale.ui_toggle=\""

And you'll get this in your terminal:

.. figure:: https://raw.githubusercontent.com/pyroscope/rtorrent-ps/master/docs/_static/img/rt-ps-network-history.png
   :align: center
   :alt: rTorrent-PS Network History

   *rTorrent-PS Network History*

As you can see, you get the upper and lower bounds of traffic within
your configured time window, and each bar of the graph represents an
interval determined by the sampling schedule. Pressing ``=`` toggles
between a graph display with base line 0, and a zoomed view that scales
it to the current bounds.


Setting Up Your Terminal
^^^^^^^^^^^^^^^^^^^^^^^^

Whatever font you use in your terminal profile, it of course has to support the
characters used in the status columns. Also, your terminal **must** be
set to use UTF-8 (which nowadays usually is the default anyway), that
means ``LANG`` should be something like ``en_US.UTF-8``, and ``LC_ALL``
and ``LC_CTYPE`` should **not** bet set at all! If you use a terminal
multiplexer like most people do, and the display doesn't look right, try
``tmux -u`` respectively ``screen -U`` to force UTF-8 mode. Also make
sure you have the ``locales`` package installed on Debian-type systems.

Connecting via SSH from Windows using PuTTY/KiTTY (version >=0.70), take a look at this small `guide <https://github.com/chros73/rtorrent-ps-ch_setup/wiki/Windows-8.1#connect-via-ssh>`_.

The following command lets you easily check whether your font supports
all the necessary characters and your terminal is configured correctly:

.. code-block:: shell

    python -c 'print u"\u22c5 \u22c5\u22c5 \u201d \u2019 \u266f \u2622 \u260d \u2318 \u2730 " \
        u"\u28ff \u26a1 \u262f \u2691 \u21ba \u2934 \u2935 \u2206 \u231a \u2240\u2207 \u2707 " \
        u"\u26a0\xa0\u25d4 \u26a1\xa0\u21af \xbf \u2a02 \u2716 \u21e3 \u21e1  \u2801 \u2809 " \
        u"\u280b \u281b \u281f \u283f \u287f \u28ff \u2639 \u2780 \u2781 \u2782 \u2783 \u2784 " \
        u"\u2785 \u2786 \u2787 \u2788 \u2789 \u25b9\xa0\u254d \u25aa \u26af \u2692 \u25cc " \
        u"\u21c5 \u21a1 \u219f \u229b \u267a ".encode("utf8")'


Supporting 256 or more colors
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Having 256 colors you can use color gradients for ratio coloring, 
and much more appropriate pallid color shades for backgrounds.

To enable 256 colors, your terminal must obviously be able to support
them at all (i.e. have a ``xterm-256color`` terminfo entry, or similar).
But even if that is the case, you often need to give a little nudge to
the terminal multiplexers; namely start ``tmux`` with the ``-2`` switch
(that forces 256 color mode), or for ``screen`` start it with the
terminal already set to 256 color mode so it can sense the underlying
terminal supports them. Take a look at the small `tmux guide <DebianInstallFromSourceTheEasyWay.rst#note-about-tmux>`_.

You can find several color configs in the `examples <examples/>`_ folder.



.. _commands:

Command Extensions
------------------

The following new commands are available.

.. contents:: List of Commands
   :local:


compare=order,command1=[,...]
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Compares two items like ``less=`` or ``greater=``, but allows to compare
by several different sort criteria, and ascending or descending order
per given field.

The first parameter is a string of order indicators, either ``aA+`` for
ascending or ``dD-`` for descending. The default, i.e. when there's more
fields than indicators, is ascending. Field types other than value or
string are treated as equal (or in other words, they're ignored). If all
fields are equal, then items are ordered in a random, but stable
fashion.

Configuration example:

.. code-block:: ini

    # VIEW: Show active and incomplete torrents (in view #9) and update every 20 seconds
    # Items are grouped into complete, incomplete, and queued, in that order.
    # Within each group, they're sorted by upload and then download speed.
    view_sort_current = active,"compare=----,d.is_open=,d.get_complete=,d.get_up_rate=,d.get_down_rate="
    schedule = filter_active, 12, 20, \
        "view_filter = active,\"or={d.get_up_rate=,d.get_down_rate=,not=$d.get_complete=}\" ; \
         view_sort=active"


ui.bind\_key=display,key,"command1=[,...]"
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Binds the given key on a specified display to execute the commands when
pressed.

-  ``display`` must be equal to ``download_list`` (currently, no other
   displays are supported).
-  ``key`` can be either a single character for normal keys, ``^`` plus
   a character for control keys, or a 4 digit octal key code.

.. important::

    This currently can NOT be used immediately when ``rtorrent.rc`` is parsed,
    so it has to be scheduled once shortly after startup (see below example).

Configuration example:

.. code-block:: ini

    # VIEW: Bind view #7 to the "rtcontrol" result
    schedule = bind_7,0,0,"ui.bind_key=download_list,7,ui.current_view.set=rtcontrol"


ui.bind\_key.verbose[.set]=0|1
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Determines whether to log key rebindings. Default is ``1``.


view.collapsed.toggle=«VIEW NAME»
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

This command changes between the normal item display where each item
takes up three lines to a more condensed form where each item only takes
up one line. Note that each view has its own state, and that if the view
name is empty, the current view is toggled. You can set the default
state in your configuration, by adding a toggle command for each view
you want collapsed after startup (the default is expanded).

Also, you should bind the current view toggle to a key, like this:

.. code-block:: ini

    schedule = bind_collapse,0,0,"ui.bind_key=download_list,*,view.collapsed.toggle="


ui.color.«TYPE».set="«COLOR DEF»"
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

These commands allow you to set colors for selected elements of the user
interface, in some cases depending on their status. You can either
provide colors by specifying the numerical index in the terminal's color
table, or by name (for the first 16 colors).

The possible color names
are "black", "red", "green", "yellow", "blue", "magenta", "cyan",
"gray", and "white"; you can use them for both text and background
color, in the form "«fg» on «bg»", and you can add "bright" in front of
a color to select a more luminous version. If you don't specify a color,
the default of your terminal is used.

Also, these additional modifiers can be placed in the color definitions,
but it depends on the terminal you're using whether they have an effect:
"bold", "standout", "underline", "reverse", "blink", and "dim".

Here's a configuration example showing all the commands and their
defaults:

.. code-block:: ini

    # UI/VIEW: Colors
    ui.color.alarm.set="bold white on red"
    ui.color.complete.set="bright green"
    ui.color.even.set=""
    ui.color.focus.set="reverse"
    ui.color.footer.set="bold bright cyan on blue"
    ui.color.incomplete.set="yellow"
    ui.color.info.set="white"
    ui.color.label.set="gray"
    ui.color.leeching.set="bold bright yellow"
    ui.color.odd.set=""
    ui.color.progress0.set="red"
    ui.color.progress20.set="bold bright red"
    ui.color.progress40.set="bold bright magenta"
    ui.color.progress60.set="yellow"
    ui.color.progress80.set="bold bright yellow"
    ui.color.progress100.set="green"
    ui.color.progress120.set="bold bright green"
    ui.color.queued.set="magenta"
    ui.color.seeding.set="bold bright green"
    ui.color.stopped.set="blue"
    ui.color.title.set="bold bright white on blue"

Note that you might need to enable support for 256 colors in your
terminal, see above for a description. You may want to create your own coloring
theme, the easiest way is to use a second shell and ``rtxmlrpc``. Try
out some colors, and add the combinations you like to your ``~/.rtorrent.rc``.

.. code-block:: shell

    # For people liking candy stores...
    rtxmlrpc ui.color.title.set "bold magenta on bright cyan"

You can use the following code in a terminal to dump a color scheme:

.. code-block:: shell

    for i in $(rtxmlrpc system.listMethods | grep ui.color. | grep -v '\.set$'); do
        echo $i = $(rtxmlrpc -r $i | tr "'" '"') ;
    done

The term-256color script can help you with showing the colors your
terminal supports, an example output using Gnome's terminal looks like
the following...

.. figure:: https://raw.githubusercontent.com/pyroscope/rtorrent-ps/master/docs/_static/img/xterm-256-color.png
   :align: center
   :alt: xterm-256-color

   *xterm-256-color*


ui.current\_view= (merged into 0.9.7+)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Returns the currently selected view, the vanilla 0.9.6 release only has
a setter.

Needed if you want to use a hyphen ``-`` as a view name in ``rtcontrol``
to refer to the currently shown view. An example for that is passing
``-M-`` as an option, which performs in-place filtering of the current
view via ``rtcontrol``.

Another use-case for this command is if you want to rotate through a set
of views via XMLRPC.


log.messages=«path»
^^^^^^^^^^^^^^^^^^^

(Re-)opens a log file that contains the messages normally only visible
on the main panel and via the ``l`` key. Each line is prefixed with the
current date and time in ISO8601 format. If an empty path is passed, the
file is closed.


network.history.\*=
^^^^^^^^^^^^^^^^^^^

Commands to add network traffic charts to the bottom of the collapsed
download display. The commands added are
``network.history.depth[.set]=``, ``network.history.sample=``,
``network.history.refresh=``, and ``network.history.auto_scale=``.


d.tracker\_domain=
^^^^^^^^^^^^^^^^^^

Returns the (shortened) tracker domain of the given download item. The
chosen tracker is the first HTTP one with active peers (seeders or
leechers), or else the first one.


trackers.alias.set\_key=«domain»,«alias»
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Sets an alias that replaces the given domain, when displayed on the
right of the collapsed canvas.

Configuration example:

.. code-block:: ini

    trackers.alias.set_key = bttracker.debian.org, Debian


trackers.alias.items=
^^^^^^^^^^^^^^^^^^^^^

Returns all the mappings in the form ``«domain»=«alias»`` as a list.

Note that domains that were not explicitly defined so far, but shown
previously, are also contained in the list, with an empty alias. So to
create a list for you to fill in the aliases, scroll through all your
items on ``main`` or ``trackers``, so you can dump the domains of all
loaded items.

Example that prints all the domains and their aliases as commands that
define them:

.. code-block:: shell

    rtxmlrpc trackers.alias.items \
        | sed -r -e 's/=/, "/' -e 's/^/trackers.alias.set_key = /' -e 's/$/"/' \
        | tee ~/rtorrent/rtorrent.d/tracker-aliases.rc

This also dumps them into the ``tracker-aliases.rc`` file to persist
your mappings, and also make them easily editable. To reload edited
alias definitions, use this:

.. code-block:: shell

    rtxmlrpc "try_import=,~/rtorrent/rtorrent.d/tracker-aliases.rc"


system.env=«name» (merged into 0.9.7+)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Returns the value of the given environment variable, or an empty string
if it does not exist.

Configuration example:

.. code-block:: ini

    session.path.set="$cat=\"$system.env=RTORRENT_HOME\",\"/.session\""


system.random=[[«lower»,]«upper»]
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Generate *uniformly* distributed random numbers in the range defined by
``lower``..``upper``.

The default range with no args is ``0`` … ``RAND_MAX``. Providing just
one argument sets an *exclusive* upper bound, and two arguments define
an *inclusive* range.

An example use-case is adding jitter to time values that you later check
with ``elapsed.greater``, to avoid load spikes and similar effects of
clustered time triggers.


throttle.names=
^^^^^^^^^^^^^^^

Returns a list of all defined throttle names, including the built-in ones (i.e. '' and NULL).


value=«number»[,«base»]
^^^^^^^^^^^^^^^^^^^^^^^

Converts a given number with the given base (or 10 as the default) to an
integer value.

Examples:

.. code-block:: console

    $ rtxmlrpc --repr value '' 1b 16
    27
    $ rtxmlrpc --repr value '' 1b
    ERROR    While calling value('', '1b'): <Fault -503: 'Junk at end of number: 1b'>


convert.human_size=«value»[,«format»]
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Converts a number (e.g. output of the first parameter) to human readable byte size format. If ``«format»`` is ``0`` use 6 chars (one decimal place), if ``1`` then just print the rounded value (4 chars), if ``2`` then combine the two formats into 4 chars by rounding for values >= 9.95. It can be used e.g. with ``log.messages`` or ``ui.column.render``:

.. code-block:: shell

    # Uploaded data (⊼)
    method.set_key = ui.column.render, "700:6:   ⊼  ", ((if, ((d.up.total)), ((convert.human_size, ((d.up.total)), (value, 0) )), ((cat, "   ·  "))))


convert.magnitude=«value»
^^^^^^^^^^^^^^^^^^^^^^^^^

Converts a number (e.g. output of the first parameter) to 2-digits number, or digit + dimension indicator (c = 10², m = 10³, X = 10⁴, C = 10⁵, M = 10⁶). It can be used e.g. with ``log.messages`` or ``ui.column.render``:

.. code-block:: shell

    # Scrape info (↺ ⤴ ⤵)
    method.set_key = ui.column.render, "400:2: ↺", ((convert.magnitude, ((d.tracker_scrape.downloaded)) ))


string.map=«cmd»,{«from1»,«to1»}[,{«from2»,«to2»},…]
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Compares a string (e.g. output of the first parameter) to ``fromx`` values and replaces them with the corresponding ``tox`` values upon a match. It can be used e.g. with ``ui.column.render``:

.. code-block:: shell

    # Override Throttle column (⊘)
    method.set_key = ui.column.render, "200:1:⊘", ((string.map, ((d.throttle_name)), {"", " "}, {NULL, "∞"}, {slowup, "⊼"}, {tardyup, "⊻"}))


string.replace=«cmd»,{«from1»,«to1»}[,{«from2»,«to2»},…]
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Replaces strings (``fromx`` values) of a string (e.g. output of the first parameter) with the corresponding ``tox`` values upon a match. Example usage:

.. code-block:: shell

    print=(string.replace,(d.name),{"Play","foo"},{"Plus","bar"})


string.contains[\_i]=«haystack»,«needle»[,…]
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Checks if a given string contains any of the strings following it. The
variant with ``_i`` is case-ignoring, but *only* works for pure ASCII
needles.

Example:

.. code-block:: shell

    rtxmlrpc d.multicall.filtered '' '' 'string.contains_i=(d.name),x264.aac' d.hash= d.name=


d.multicall.filtered=«viewname»,«condition»,«command»[,…]
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Iterates over all items of a view (or ``default`` if the view name is
empty), just like ``d.multicall2``, but only calls the given commands if
``condition`` is true for an item.

See directly above for an example.


ui.focus.[home|end|pgup|pgdn]=
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Commands that can be assigned to keyboard schortcuts (with the help of ``ui.bind_key`` command) to jump to the first / last item in the current view or scroll by 50 items up or down at a time (or whatever other value ui.focus.page_size has). An example keyboard shortcut assignements:

.. code-block:: ini

    schedule = navigation_home,0,0,"ui.bind_key=download_list,0406,ui.focus.home="
    schedule = navigation_end, 0,0,"ui.bind_key=download_list,0550,ui.focus.end="
    schedule = navigation_pgup,0,0,"ui.bind_key=download_list,0523,ui.focus.pgup="
    schedule = navigation_pgdn,0,0,"ui.bind_key=download_list,0522,ui.focus.pgdn="


ui.focus.page_size[.set]=«value»
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Get / set the number of items to scroll with ``ui.focus.pgup`` or ``ui.focus.pgdn``. Default value: ``50``.


ui.style.[progress|ratio][.set]=«value»
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Get / set the value of style to use in ``completion status`` (values from ``0`` to ``2``) and ``ratio`` (values from ``0`` to ``3``) columns. Value ``0`` is a *mostly* ASCII one for both. Default value for both: ``1``.


system.colors.max=
^^^^^^^^^^^^^^^^^^

Returns the max number of colors the underlying system supports.


system.colors.enabled=
^^^^^^^^^^^^^^^^^^

Returns boolean, determines whether the underlying system (ncurses) has coloring support.


system.colors.rgb=
^^^^^^^^^^^^^^^^^^

Returns boolean, determines whether the underlying system (ncurses) can change colors. (This always returns ``0`` for whatever reason.)


ui.column.render
^^^^^^^^^^^^^^^^

Multi-command to hold column definitions, used on the collapsed canvas to render all the columns except for Name and Tracker Domain columns. 
See the `Columns in the collapsed display <#columns-in-the-collapsed-display>`_ section above for built-in column key definitions.

Here's a configuration example showing all the built-in columns and their defaults:

.. code-block:: ini

    # Status flags (☢ ☍ ⌘ ✰)
    method.set_key = ui.column.render, "100:1:☢", ((string.map, ((cat, ((d.is_open)), ((d.is_active)))), {00, "▪"}, {01, "▪"}, {10, "╍"}, {11, "▹"}))
    method.set_key = ui.column.render, "110:1:☍", ((if, ((d.tied_to_file)), ((cat, "⚯")), ((cat, " "))))
    method.set_key = ui.column.render, "120:1:⌘", ((if, ((d.ignore_commands)), ((cat, "◌")), ((cat, "⚒"))))
    method.set_key = ui.column.render, "130:1:✰", ((string.map, ((cat, ((d.priority)))), {0, "✖"}, {1, "⇣"}, {2, " "}, {3, "⇡"}))
    # First character of throttle name (⊘)
    method.set_key = ui.column.render, "200:1:⊘", {(branch, ((equal,((d.throttle_name)),((cat,NULL)))), ((cat, "∞")), ((d.throttle_name)) )}
    # Completion status (⣿)
    method.set_key = ui.column.render, "300:2:⣿ ", ((d.ui.completion))
    # Transfer direction (⋮)
    method.set_key = ui.column.render, "310:1:⋮", ((if, ((d.down.rate)), ((if,((d.up.rate)),((cat, "⇅")),((cat, "↡")))), ((if,((d.up.rate)),((cat, "↟")),((cat, " ")))) ))
    # Ratio (☯)
    method.set_key = ui.column.render, "320:2:☯ ", ((d.ui.ratio))
    # Message (⚑)
    method.set_key = ui.column.render, "330:2:⚑ ", ((d.ui.message))
    # Scrape info (↺ ⤴ ⤵)
    method.set_key = ui.column.render, "400:2: ↺", ((convert.magnitude, ((d.tracker_scrape.downloaded)) ))
    method.set_key = ui.column.render, "410:2: ⤴", ((convert.magnitude, ((d.tracker_scrape.complete)) ))
    method.set_key = ui.column.render, "420:2: ⤵", ((convert.magnitude, ((d.tracker_scrape.incomplete)) ))
    # Number of connected peers (↻)
    method.set_key = ui.column.render, "430:2: ↻", ((convert.magnitude, ((d.peers_connected)) ))
    # Uprate or approximate time since last active state (⌬ ≀∆)
    method.set_key = ui.column.render, "600:5: ⌬ ≀∆", ((d.ui.uprate_tm))
    # Uploaded data (⊼)
    method.set_key = ui.column.render, "700:6:   ⊼  ", ((if, ((d.up.total)), ((convert.human_size, ((d.up.total)), (value, 0) )), ((cat, "   ·  "))))
    # Downrate or approximate time since completion (⌬ ≀∇)
    method.set_key = ui.column.render, "800:5: ⌬ ≀∇", ((d.ui.downrate_tm))
    # Selected data size (✇)
    method.set_key = ui.column.render, "900:4:  ✇ ", ((convert.human_size, ((d.selected_size_bytes)) ))

To disable or override built-in columns or add new ones:

.. code-block:: ini

    # Disable Number of connected peers (↻) column
    method.set_key = ui.column.render, "430:2: ↻"
    # Override Throttle column (⊘)
    method.set_key = ui.column.render, "200:1:⊘", ((string.map, ((d.throttle_name)), {"", " "}, {NULL, "∞"}, {slowup, "⊼"}, {tardyup, "⊻"}))
    # Add Unsafe data column (◎)
    method.set_key = ui.column.render, "230:1:◎", ((string.map, ((cat, ((d.custom,unsafe_data)))), {0, " "}, {1, "⊘"}, {2, "⊗"}))
    # Add Data directory column (⊕) (first character of parent directory)
    method.set_key = ui.column.render, "250:1:⊕", ((d.parent_dir))


event.view.[hide|show]
^^^^^^^^^^

Events (multi commands) that will be triggered upon view changes: first ``event.view.hide`` group is triggered then ``event.view.show`` group. Example usage:

.. code-block:: ini

    method.set_key = event.view.hide, ~log, ((print, ((ui.current_view)), " → ", ((argument.0))))


event.download.partially_restarted
^^^^^^^^^^

Event (multi commands) that will be triggered when a download is being partially restarted: when previously deselected files are selected of a finished download. Example usage:

.. code-block:: ini

    method.set_key = event.download.partially_restarted, ~log, ((print, "Partially restarted : ", ((d.name))))


d.custom[.set]=last_active|tm_completed[,«timestamp»]
^^^^^^^^^^

Custom fileds ``d.custom=last_active`` and ``d.custom=tm_completed`` hold timestamps: the last time when items had peers and time of completion. They are also displayed on the collapsed display.


d.allocatable_size_bytes=
^^^^^^^^^^

Returns the size needed to create the selected files of a download in Bytes.


d.parent_dir=
^^^^^^^^^^^^^

Returns the name of the parent directory of a download.


d.tracker_scrape.[downloaded|complete|incomplete]=
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Return the number of downloads / seeders / leechers acquired during scraping request.


d.selected_size_bytes=
^^^^^^^^^^

Returns the size of the selected files of a download in Bytes. It returns the ``completed_bytes`` if a download is only partyally done (and not the slected size of files, since they can be turnd off later!), or calculates the partial size based on the selected chunks of the selected files if a downalod hasn't been (partially) finished.


d.is_enough_diskspace=
^^^^^^^^^^

Returns boolean, determines whether there's enough space for the selected files of a download on the selected partition of an HDD.


d.is_done=
^^^^^^^^^^

Returns boolean, determines whether all the files of a download have been finished (to be able to distinguish between finished and partially done downloads).


d.is_meta= (merged into 0.9.7+)
^^^^^^^^^^

Returns boolean, determines whether a download is meta download of magnet URI.


f.is_fallocatable=
^^^^^^^^^^

Returns boolean, determines whether a file has ``flag_fallocate`` flag.


f.is_fallocatable_file=
^^^^^^^^^^

Returns boolean, determines whether a file has both ``flag_fallocate`` and ``flag_resize_queued`` flag.


f.[un]set_fallocate=
^^^^^^^^^^

``f.set_fallocate`` and ``f.unset_fallocate`` commands are setter methods for ``flag_fallocate`` flag of a file.


convert.group=«cmd»
^^^^^^^^^^

Returns a formatted (2 characters padded) string for a number, e.g.: ``--``, `` 2``, ``125``. It's used to display max choke group values on Info screen.


directory.watch.added=«dir»,«cmd»[,«cmd1»,«cmd2»,…]
^^^^^^^^^^^^^^^^^^^^^^^

`directory.watch.added <https://github.com/chros73/rtorrent-ps-ch/issues/87>`_ adds ``inotify`` support for added meta files.

First parameter is the directory that will be watched, second is the name of the main command that will be called if an "add" event is triggered (``load.*`` commands), while the rest of the parameters are  a comma separated list of extra commands that will be passed as arguments to the main command specified as the second parameter. Note that if an extra command includes commas (``,`` parameter separator) then it needs to be included inside quotes (``"``). Limitation: a given directory can only be specified once with either  ``directory.watch.added`` or ``directory.watch.removed``.

.. code-block:: ini

    directory.watch.added = (cat,(cfg.dir.meta_downl),unsafe/),   load.start,  "d.attribs.set=unsafe,,1", print=loadedunsafe


directory.watch.removed=«cmd»,«dir1»[,«dir2»,…]
^^^^^^^^^^^^^^^^^^^^^^^

`directory.watch.removed <https://github.com/chros73/rtorrent-ps-ch/issues/87>`_ adds ``inotify`` support for removed meta files.

It only supports 3 commands as the first parameter: ``d.stop``, ``d.close``, ``d.erase``; rest of the parameters are a comma separated list of the directories that will be watched. Limitation: a given directory can only be specified once with either  ``directory.watch.added`` or ``directory.watch.removed``.

.. code-block:: ini

    directory.watch.removed = d.erase, (cat,(cfg.dir.meta_compl),various/), (cat,(cfg.dir.meta_compl),unsafe/)


chars.chop=«text»[,«length»[,0|1]]
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Chop a string or a number to the given ``«length»``, if third parameter is set to ``1`` then ``…`` character is appended to the chopped string. It's UTF-8 aware and also can be chained together with other ``chars.*`` commands. 

.. code-block:: ini

    # Result: 12…
    print=(chars.chop, "1234567", 3, 1)
    # Result: 123xx
    print=(chars.pad, (chars.chop, "1234567", 3), 5, "x")


chars.pad=«text»[,«length»[,«char»[,0|1]]]
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Pad a string or a number to the given ``«length»`` with the specified ``«char»`` character (default is `` `` space), if fourth parameter is set to ``1`` then padding left is applied, otherwise padding right. It's UTF-8 aware and also can be chained together with other ``chars.*`` commands. 

.. code-block:: ini

    # Result: 00123
    print=(chars.pad, "123", 5, "0", 1)
    # Result: 123xx
    print=(chars.pad, (chars.chop, "1234567", 3), 5, "x")


math.[add|sub|mul|div|mod|min|max|cnt|avg|med]=«cmd1»[,«cmd2»,…]
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``math.*`` command group adds support for basic arithmetic operators (``+``, ``-``, ``*``, ``/``, ``%``) and ``min``, ``max``, ``count``, ``avg``, ``median`` functions. They support multiple arguments, even list type as well, they also can be chained together, but restricted to integer arithmetic only (as in ``bash``): ``/``, ``avg``, ``median`` always round down. 

.. code-block:: ini

    # Subtract 3 numbers: -4
    print=(math.subtract,5,2,7)
    # Divide 3 numbers: 2 !
    print=(math.divide,80,9,4)

    # Calculate size of a download using its size of files (example using list type)
    print=(math.add,(f.multicall,,f.size_bytes=))
    # Get average size in Bytes of downloads in main view
    print=(math.divide,(math.add,(d.multicall2,main,d.size_bytes=)),(view.size,main))
    
    # Assign 0 if value smaller than 0, or assign value otherwise ( x >= 0 ? x : 0 )
    print=(math.max,0,(math.subtract,2,7))
    # Assign 0 if value smaller than 0, 100 if value is bigger than 100, or assign value otherwise ( x < 0 ? 0 : (x > 100 ? 100 : x) )
    print=(math.max,0,(math.min,100,(math.divide,500,2)))


match=«cmd1»,«cmd2»
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Regexp based comparison operator can work with strings or values (integers), returned from the given commands, its return value is boolean. 

.. code-block:: ini

    method.insert = match_name, simple, "match={d.name=,.*linux.*iso}"


view.temp_filter=«viewname»[,«cmd»]
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Apply temp filter to a view. If ``«cmd»`` isn't supplied it removes the previously applied temp filter.

.. code-block:: ini

    view.temp_filter=main, "match={d.name=,.*linux.*iso}"


view.temp_filter.excluded[.set]="[«viewname1»,«viewname2»,…]"
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Get / set a list of views that can be excluded from subfiltering. Its default value is:

.. code-block:: ini

    view.temp_filter.excluded.set="default,started,stopped"


view.temp_filter.log[.set]=0|1
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Determines whether subfiltering is logged onto the messages view (key `l`). Disabled by default, to enable it:

.. code-block:: ini

    view.temp_filter.log.set=1


ui.input.history.size[.set]=«value»
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Get / set the size of `input history <https://github.com/chros73/rtorrent-ps-ch/issues/83>`_. Default value is:

.. code-block:: ini

    ui.input.history.size.set=99


ui.input.history.clear=
^^^^^^^^^^^^^^^^^^^^^^^

Clear all the `input history <https://github.com/chros73/rtorrent-ps-ch/issues/83>`_.


ui.status.throttle.[up|down][.set]=«throttlename»[,«throttlename»]
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Displays values of the given ``throttle.up``/``throttle.down`` in the first part of status bar, multiple comma separated names can be given.
Include the max limit of the throttle, the main upload/download rate and the upload/download rate of the throttle (in this order).

Original: ``[Throttle 500/1500 KB] [Rate: 441.6/981.3 KB]``

Modified possible cases:

.. code-block::

    [Throttle 200 / 500 KB] [Rate 107.4 / 298.6 KB]
    [Throttle 200(114) / 500 KB] [Rate 107.0(1.0|105.9) / 307.6 KB]
    [Throttle 200 / 500(250) KB] [Rate 124.7 / 298.2(298.2|0.0) KB]
    [Throttle 200(114) / 500(250) KB] [Rate 115.9(1.7|114.2) / 333.9(333.9|0.0) KB]
    [Throttle 500(154|25) / 1500 KB] [Rate 399.6(365.9|8.3|25.4) / 981.3 KB]

Limitation is that every group (there are 4 possible groups) can contain the following number of characters (it leaves space for at least 5 throttles to be displayed): 40 chars for limits, 50 chars for rates.

This extra info isn't displayed in the following cases:

   - there isn't any ``throttle.up``/``throttle.down`` name as the config variable suggest or the given name is "NULL"
   - ``throttle.up``/``throttle.down`` is not throttled (=0)
   - the global upload/download is not throttled (=0) (``throttle.up``/``throttle.down`` won't be taken into account in this case)

Configuration example:

.. code-block:: ini

    ui.status.throttle.up.set=slowup,tardyup
    ui.status.throttle.down.set=slowdown


ui.throttle.global.step.[small|medium|large][.set]=«value»
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Set `global throttle steps <https://github.com/rakshasa/rtorrent/wiki/User-Guide#throttling>`_. Their default value is:

.. code-block:: ini

    ui.throttle.global.step.small.set  =   5
    ui.throttle.global.step.medium.set =  50
    ui.throttle.global.step.large.set  = 500


d.ui.*=
^^^^^^^

Commands to display various information that require coloring support on the collapsed download display. The commands added are ``d.ui.message``, ``d.ui.completion``, ``d.ui.ratio``, ``d.ui.uprate_tm``, ``d.ui.downrate_tm`` .


