> Only a compound can be beautiful, never anything devoid of parts; and only a whole;<br>
> the several parts will have beauty, not in themselves,<br>
> but only as working together to give a comely total.<br>
> Yet beauty in an aggregate demands beauty in details:<br>
> it cannot be constructed out of ugliness; its law must run throughout.

– [Plotinus](https://en.wikipedia.org/wiki/Plotinus), *First Ennead*


<h1 align="center">Plotinus</h1>
<h3 align="center">A searchable command palette in every modern GTK+ application</h3>
<br>

Have you used Sublime Text's or Atom's "Command Palette"? It's a list of everything those editors can do that opens at the press of a key and finds the action you are looking for just by typing a few letters. It's raw power at your fingertips.

Plotinus brings that power ***to every application on your system*** (that is, to those that use the GTK+ 3 toolkit). It automatically extracts all available commands by introspecting a running application, instantly adapting to UI changes and showing only relevant actions. Using Plotinus requires *no modifications* to the application itself!

Just press <kbd>Ctrl+Shift+P</kbd> ([configurable](#configuration)) and you're in business – it feels so natural you'll soon wonder how you ever lived without it.

![Nautilus screencast](https://cloud.githubusercontent.com/assets/2702526/20246717/454a1a9a-a9e3-11e6-8b19-4db092348793.gif)

![gedit screencast](https://cloud.githubusercontent.com/assets/2702526/20246718/5397bed6-a9e3-11e6-8023-aa9a318820e3.gif)


## Installation

### Prerequisites

To build Plotinus from source, you need Git, CMake, Vala, and the GTK+ 3 development files. All of these are easily obtained on most modern Linux distributions:

#### Fedora / RHEL / etc.

```
sudo dnf install git cmake vala gtk3-devel
```

#### Ubuntu / Mint / Elementary / etc.

```
sudo apt-get install git cmake valac libgtk-3-dev
```

### Building

```
git clone https://github.com/p-e-w/plotinus.git
cd plotinus
mkdir build
cd build
cmake ..
make
sudo make install
```

### Enabling Plotinus in applications

Because of the complexity and clumsiness surrounding Linux environment variables, Plotinus is currently not enabled automatically. The easiest way to enable Plotinus for all applications on the system is to add the line

```
GTK3_MODULES=[libpath]
```

to `/etc/environment`, where `[libpath]` is the *full, absolute* path of `libplotinus.so`, which can be found using the command

```
whereis -b libplotinus
```

Alternatively, you can try Plotinus with individual applications by running them with

```
GTK3_MODULES=[libpath] application
```

from a terminal.


## Configuration

Plotinus can be configured both globally and per application. Application settings take precedence over global settings. In the commands below, `[application]` can be either

* `default`, in which case the setting is applied globally, or
* the path of an application executable, without the leading slash and with all other slashes replaced by periods (e.g. `/usr/bin/gedit` -> `usr.bin.gedit`).

Note that the relevant path is the path of the *process executable*, which is not always identical to the executable being launched. For example, all GNOME JavaScript applications run the process `/usr/bin/gjs`.

### Enabling/disabling the command palette

```
gsettings set com.worldwidemann.plotinus:/com/worldwidemann/plotinus/[application]/ enabled [true/false]
```

### Changing the keyboard shortcut

```
gsettings set com.worldwidemann.plotinus:/com/worldwidemann/plotinus/[application]/ hotkeys '[keys]'
```

`[keys]` must be an array of strings in the format expected by [`gtk_accelerator_parse`](https://developer.gnome.org/gtk3/stable/gtk3-Keyboard-Accelerators.html#gtk-accelerator-parse), e.g. `["<Primary><Shift>P", "<Primary>P"]`. Each shortcut in the array opens the command palette.

### Enabling/disabling D-Bus window registration

```
gsettings set com.worldwidemann.plotinus:/com/worldwidemann/plotinus/[application]/ dbus-enabled [true/false]
```

See the following section for details.


## D-Bus API

Plotinus provides a simple but complete [D-Bus](https://www.freedesktop.org/wiki/Software/dbus/) API for developers who want to use its functionality from their own software. The API consists of two methods, exposed on the session bus at `com.worldwidemann.plotinus`:

* `GetCommands(window_path) -> (bus_name, command_paths)`<br>Takes the object path of a GTK+ window (which can e.g. be obtained from a Mutter window via [`meta_window_get_gtk_window_object_path`](https://developer.gnome.org/meta/stable/MetaWindow.html#meta-window-get-gtk-window-object-path)) and returns an array of object paths referencing commands extracted from that window, as well as the name of the bus on which they are registered.<br>The mechanism behind this method is somewhat similar to [Ubuntu's AppMenu Registrar](https://github.com/tetzank/qmenu_hud/blob/master/com.canonical.AppMenu.Registrar.xml), but more lightweight and compatible with Wayland. Window registration [must be enabled](#enablingdisabling-dbus-window-registration) before using this method.

* `ShowCommandPalette(commands) -> (bus_name, command_palette_path)`<br>Takes an array of commands (structs of the form `(path, label, accelerators)`) and opens a command palette window displaying those commands. The returned object path references a control object registered on the returned bus name which provides signals on user interaction with the window.

Calls to these methods are processed by the **Plotinus D-Bus service,** which can be started with

```
plotinus
```

### Examples

The following examples demonstrate how to use the D-Bus API from Python. They require [pydbus](https://github.com/LEW21/pydbus) to be installed and the Plotinus D-Bus service to be running.

#### Application remote control

```python
#!/usr/bin/env python

import sys
from pydbus import SessionBus

bus = SessionBus()
plotinus = bus.get("com.worldwidemann.plotinus")

bus_name, command_paths = plotinus.GetCommands(sys.argv[1])
commands = [bus.get(bus_name, command_path) for command_path in command_paths]

for i, command in enumerate(commands):
  print("[%d] %s -> %s" % (i, " -> ".join(command.Path), command.Label))

index = raw_input("Number of command to execute: ")

if index:
  commands[int(index)].Execute()
```

Before running this example, enable window registration with

```
gsettings set com.worldwidemann.plotinus:/com/worldwidemann/plotinus/default/ dbus-enabled true
```

Then, run an application (e.g. gedit) with [Plotinus enabled](#enabling-plotinus-in-applications). Now run the script with the window object path as an argument, i.e.

```
./application_remote_control.py /org/gnome/gedit/window/1
```

#### Application launcher

Based on [this Argos plugin](https://github.com/p-e-w/argos#launcherpy), uses Plotinus' command palette to display a list of applications available on the system.

```python
#!/usr/bin/env python

import os, re
from pydbus import SessionBus
from gi.repository import GLib, Gio

applications = {}

for app_info in Gio.AppInfo.get_all():
  categories = app_info.get_categories()
  if categories is None:
    continue
  # Remove "%U" and "%F" placeholders
  command_line = re.sub("%\\w", "", app_info.get_commandline()).strip()
  app = (app_info.get_name(), command_line)
  for category in categories.split(";"):
    if category not in ["GNOME", "GTK", ""]:
      if category not in applications:
        applications[category] = []
      applications[category].append(app)
      break

commands = []
command_lines = []

for category, apps in sorted(applications.items()):
  for app in sorted(apps):
    commands.append(([category], app[0], []))
    command_lines.append(app[1])

bus = SessionBus()
plotinus = bus.get("com.worldwidemann.plotinus")

bus_name, command_palette_path = plotinus.ShowCommandPalette(commands)
command_palette = bus.get(bus_name, command_palette_path)

loop = GLib.MainLoop()

def command_executed(index):
  os.system(command_lines[index])

command_palette.CommandExecuted.connect(command_executed)

def closed():
  # Wait for CommandExecuted signal
  GLib.timeout_add(500, loop.quit)

command_palette.Closed.connect(closed)

loop.run()
```


## Acknowledgments

Documentation on GTK+ modules is essentially nonexisting. Without [gtkparasite](https://github.com/chipx86/gtkparasite) and [gnome-globalmenu](https://github.com/gnome-globalmenu/gnome-globalmenu) to learn from, it would have been a lot harder to get this project off the ground.

The CMake modules are copied verbatim from Elementary's [pantheon-installer](https://github.com/elementary/pantheon-installer) repository.

Vala is still the greatest thing ever to happen to Linux Desktop development.


## Contributing

Contributors are always welcome. However, **please file an issue describing what you intend to add before opening a pull request,** *especially* for new features! I have a clear vision of what I want (and do not want) Plotinus to be, so discussing potential additions might help you avoid duplication and wasted work.

By contributing, you agree to release your changes under the same license as the rest of the project (see below).


## License

Copyright &copy; 2016-2017 Philipp Emanuel Weidmann (<pew@worldwidemann.com>)

Released under the terms of the [GNU General Public License, version 3](https://gnu.org/licenses/gpl.html)
