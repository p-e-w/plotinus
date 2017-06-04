/*
 * Plotinus - A searchable command palette in every modern GTK+ application
 *
 * Copyright (c) 2016-2017 Philipp Emanuel Weidmann <pew@worldwidemann.com>
 *
 * Nemo vir est qui mundum non reddat meliorem.
 *
 * Released under the terms of the GNU General Public License, version 3
 * (https://gnu.org/licenses/gpl.html)
 */

namespace Plotinus {

  void main(string[] argv) {
    Gtk.init(ref argv);

    Bus.own_name(BusType.SESSION, "com.worldwidemann.plotinus", BusNameOwnerFlags.NONE,
        (connection) => connection.register_object("/com/worldwidemann/plotinus", new Service(connection)));

    Gtk.main();
  }

  [DBus(name="com.worldwidemann.plotinus")]
  class Service : Object, ServiceProxy {
    private DBusConnection connection;

    private HashTable<string, CommandProviderProxy> command_providers =
        new HashTable<string, CommandProviderProxy>(str_hash, str_equal);

    public Service(DBusConnection connection) {
      this.connection = connection;
    }

    public void get_commands(ObjectPath window_path, out string bus_name, out ObjectPath[] command_paths) {
      if (command_providers.contains(window_path)) {
        command_providers.get(window_path).get_commands(out bus_name, out command_paths);
      } else {
        // Returning null here instead of an empty string leads to a segmentation fault
        bus_name = "";
        command_paths = {};
      }
    }

    public void register_window(ObjectPath window_path, string bus_name, ObjectPath command_provider_path) {
      // Using get_proxy_sync here leads to a deadlock
      Bus.get_proxy.begin<CommandProviderProxy>(BusType.SESSION, bus_name, command_provider_path,
          DBusProxyFlags.NONE, null, (source_object, result) => {
        CommandProviderProxy command_provider = Bus.get_proxy.end(result);
        command_providers.replace(window_path, command_provider);
      });
    }

    public void unregister_window(ObjectPath window_path) {
      command_providers.remove(window_path);
    }

    public void show_command_palette(CommandStruct[] commands,
        out string bus_name, out ObjectPath command_palette_path) {
      bus_name = connection.unique_name;
      command_palette_path =
          new ObjectPath("/com/worldwidemann/plotinus/CommandPalette/%s".printf(DBus.generate_guid()));
      connection.register_object(command_palette_path, new CommandPalette(commands));
    }
  }

  [DBus(name="com.worldwidemann.plotinus")]
  interface ServiceProxy : Object {
    public abstract void get_commands(ObjectPath window_path, out string bus_name, out ObjectPath[] command_paths);
    public abstract void register_window(ObjectPath window_path, string bus_name, ObjectPath command_provider_path);
    public abstract void unregister_window(ObjectPath window_path);
    public abstract void show_command_palette(CommandStruct[] commands,
        out string bus_name, out ObjectPath command_palette_path);
  }

  [DBus(name="com.worldwidemann.plotinus.CommandProvider")]
  class CommandProvider : Object, CommandProviderProxy {
    private DBusConnection connection;
    private CommandExtractor command_extractor;
    private Gtk.Window window;

    public CommandProvider(DBusConnection connection, CommandExtractor command_extractor, Gtk.Window window) {
      this.connection = connection;
      this.command_extractor = command_extractor;
      this.window = window;
    }

    public void get_commands(out string bus_name, out ObjectPath[] command_paths) {
      ObjectPath[] command_paths_builder = {};

      foreach (var command in command_extractor.get_window_commands(window)) {
        var command_path = new ObjectPath("/com/worldwidemann/plotinus/Command/%s".printf(DBus.generate_guid()));
        connection.register_object(command_path, command);
        command_paths_builder += command_path;
      }

      bus_name = connection.unique_name;
      command_paths = command_paths_builder;
    }
  }

  [DBus(name="com.worldwidemann.plotinus.CommandProvider")]
  interface CommandProviderProxy : Object {
    public abstract void get_commands(out string bus_name, out ObjectPath[] command_paths);
  }

  struct CommandStruct {
    public string[] path;
    public string label;
    public string[] accelerators;
  }

  [DBus(name="com.worldwidemann.plotinus.CommandPalette")]
  class CommandPalette : Object {
    private PopupWindow popup_window;

    public CommandPalette(CommandStruct[] commands) {
      Command[] command_objects = {};

      for (var i = 0; i < commands.length; i++) {
        var command = commands[i];
        var command_object = new SignalCommand(command.path, command.label, command.accelerators);

        var index = i;
        command_object.executed.connect(() => command_executed(index));

        command_objects += command_object;
      }

      popup_window = new PopupWindow(command_objects);
      popup_window.destroy.connect(() => closed());
      popup_window.show_all();
    }

    public void close() {
      popup_window.destroy();
    }

    public signal void closed();

    public signal void command_executed(int index);
  }

  class ServiceClient : Object {
    private Gtk.Application application;
    private CommandExtractor command_extractor;
    private DBusConnection connection;
    private ServiceProxy service;

    public ServiceClient(Gtk.Application application, CommandExtractor command_extractor) {
      this.application = application;
      this.command_extractor = command_extractor;
      connection = Bus.get_sync(BusType.SESSION);
      service = Bus.get_proxy_sync(BusType.SESSION, "com.worldwidemann.plotinus", "/com/worldwidemann/plotinus");
    }

    public void register_window(Gtk.Window window) {
      var window_path = get_window_path(window);
      if (window_path == null)
        return;

      var command_provider = new CommandProvider(connection, command_extractor, window);
      var command_provider_path = new ObjectPath(
          "/com/worldwidemann/plotinus/CommandProvider/%s".printf(DBus.generate_guid()));

      connection.register_object(command_provider_path, command_provider);

      service.register_window(window_path, connection.unique_name, command_provider_path);
    }

    public void unregister_window(Gtk.Window window) {
      var window_path = get_window_path(window);
      if (window_path == null)
        return;

      service.unregister_window(window_path);
    }

    private ObjectPath? get_window_path(Gtk.Window window) {
      var application_window = window as Gtk.ApplicationWindow;
      if (application_window == null)
        return null;

      // Default D-Bus window path assigned to ApplicationWindows
      // (see gtkapplication-dbus.c in the GTK+ source code)
      return new ObjectPath("%s/window/%u".printf(application.get_dbus_object_path(), application_window.get_id()));
    }
  }

}
