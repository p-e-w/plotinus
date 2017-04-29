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

// The module shares its global namespace with the host application,
// so all code should reside in a private namespace
namespace Plotinus {

  const uint SCAN_INTERVAL = 100;

  // Method signature adapted from https://github.com/gnome-globalmenu/gnome-globalmenu
  [CCode(cname="gtk_module_init")]
  public void gtk_module_init([CCode(array_length_pos=0.9)] ref unowned string[] argv) {
    Gtk.init(ref argv);

    // See http://stackoverflow.com/a/606057
    var executable_path = FileUtils.read_link("/proc/%u/exe".printf(Posix.getpid()));

    var instance_name = executable_path.substring(1).replace("/", ".");
    var settings = new InstanceSettings("com.worldwidemann.plotinus", "default", instance_name);

    if (!settings.get_value("enabled").get_boolean())
      return;

    Timeout.add(SCAN_INTERVAL, () => {
      Keybinder? keybinder = null;
      CommandExtractor? command_extractor = null;

      var application = Application.get_default() as Gtk.Application;

      if (application != null) {
        var application_name = "Application";

        // Try to determine the actual name of the application
        if (application.application_id != null) {
          var id_parts = application.application_id.split(".");
          application_name = id_parts[id_parts.length - 1];

          // In many cases, the AppInfo ID follows this convention
          var app_info_id = (application.application_id + ".desktop").casefold();
          AppInfo.get_all().foreach((app_info) => {
            if (app_info.get_id().casefold() == app_info_id)
              application_name = app_info.get_name();
          });
        }

        keybinder = new ApplicationKeybinder(application);
        command_extractor = new CommandExtractor.with_application(application, application_name);

      } else if (Gtk.Window.list_toplevels().length() > 0) {
        // There is no Gtk.Application yet but there are already Gtk.Windows.
        // Since creating an Application is almost always the first thing a program does,
        // this means that the program probably does not use Gtk.Application at all.
        keybinder = new WindowKeybinder();
        command_extractor = new CommandExtractor();
      }

      if (keybinder != null && command_extractor != null) {
        keybinder.keys_pressed.connect((window) => {
          var commands = command_extractor.get_window_commands(window);

          if (commands.length > 0) {
            var popup_window = new PopupWindow(commands);
            popup_window.transient_for = window;
            popup_window.show_all();
          }
        });

        keybinder.set_keys(settings.get_value("hotkeys").dup_strv());

        return false;
      }

      return true;
    });
  }

}
