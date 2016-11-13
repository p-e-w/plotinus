/*
 * Plotinus - A searchable command palette in every modern GTK+ application
 *
 * Copyright (c) 2016 Philipp Emanuel Weidmann <pew@worldwidemann.com>
 *
 * Nemo vir est qui mundum non reddat meliorem.
 *
 * Released under the terms of the GNU General Public License, version 3
 * (https://gnu.org/licenses/gpl.html)
 */

using Plotinus.Utilities;

class Plotinus.Plotinus : Object {

  private static const string ACTION_NAME = "activate-plotinus";

  private Gtk.Application application;
  private CommandExtractor command_extractor;

  public Plotinus(Gtk.Application application) {
    this.application = application;

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

    command_extractor = new CommandExtractor(application, application_name);

    var action = new SimpleAction(ACTION_NAME, null);
    action.activate.connect(() => {
      if (application.active_window != null) {
        var commands = command_extractor.get_window_commands(application.active_window);
        if (commands.length > 0)
          show_popup_window(application.active_window, commands);
      }
    });
    application.add_action(action);
  }

  public void set_hotkeys(string[] hotkeys) {
    application.set_accels_for_action("app." + ACTION_NAME, hotkeys);
  }

  private void show_popup_window(Gtk.Window parent_window, Command[] commands) {
    if ((parent_window.get_window().get_state() & Gdk.WindowState.FULLSCREEN) == Gdk.WindowState.FULLSCREEN)
      // The popup cannot be shown while the parent window is in fullscreen state
      parent_window.unfullscreen();

    var window = new Gtk.Window();
    window.skip_taskbar_hint = true;
    window.transient_for = parent_window;
    window.destroy_with_parent = true;

    window.window_position = Gtk.WindowPosition.CENTER_ON_PARENT;
    window.set_keep_above(true);

    // Width is determined by the width of the search entry
    window.set_default_size(-1, 300);
    window.set_size_request(-1, 200);

    var scrolled_window = new Gtk.ScrolledWindow(null, null);
    scrolled_window.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
    window.add(scrolled_window);

    var command_list = new CommandList(commands);
    command_list.select_first_item();
    command_list.can_focus = false;
    scrolled_window.add(command_list);

    var header_bar = new Gtk.HeaderBar();
    window.set_titlebar(header_bar);

    var search_entry = new Gtk.SearchEntry();
    // TODO: This is currently an unfortunate necessity as stable versions of GTK+
    //       do not support expanding packed widgets. The fix will be in a future release
    //       (see https://bugzilla.gnome.org/show_bug.cgi?id=724332).
    search_entry.set_size_request(600, -1);
    header_bar.custom_title = search_entry;

    search_entry.changed.connect(() => {
      command_list.set_filter(search_entry.text);
      command_list.select_first_item();
    });

    search_entry.activate.connect(() => {
      var command = command_list.get_selected_command();
      if (command != null) {
        window.destroy();
        command.execute();
      }
    });
    command_list.row_activated.connect(() => search_entry.activate());

    window.add_events(Gdk.EventMask.FOCUS_CHANGE_MASK);
    window.focus_out_event.connect(() => {
      window.destroy();
      return true;
    });

    window.add_events(Gdk.EventMask.KEY_PRESS_MASK);
    window.key_press_event.connect((event) => {
      if (event.keyval == Gdk.Key.Escape) {
        window.destroy();
        return true;
      } else if (event.keyval == Gdk.Key.Tab || event.keyval == Gdk.Key.ISO_Left_Tab) {
        // Disable Tab and Shift+Tab to prevent navigating focus away from the search entry
        return true;
      } else if (event.keyval == Gdk.Key.Up) {
        command_list.select_previous_item();
        return true;
      } else if (event.keyval == Gdk.Key.Down) {
        command_list.select_next_item();
        return true;
      }
      return false;
    });

    window.show_all();
    search_entry.grab_focus();
  }

}
