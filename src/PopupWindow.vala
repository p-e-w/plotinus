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

class Plotinus.PopupWindow : Gtk.Window {

  public PopupWindow(Command[] commands) {
    skip_taskbar_hint = true;
    destroy_with_parent = true;

    window_position = Gtk.WindowPosition.CENTER_ON_PARENT;
    set_keep_above(true);

    // Width is determined by the width of the search entry
    set_default_size(-1, 300);
    set_size_request(-1, 200);

    var scrolled_window = new Gtk.ScrolledWindow(null, null);
    scrolled_window.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
    add(scrolled_window);

    var command_list = new CommandList(commands);
    command_list.select_first_item();
    command_list.can_focus = false;
    scrolled_window.add(command_list);

    var header_bar = new Gtk.HeaderBar();
    header_bar.spacing = 0;
    set_titlebar(header_bar);

    var search_entry = new Gtk.SearchEntry();
    // TODO: This is currently an unfortunate necessity as stable versions of GTK+
    //       do not support expanding packed widgets. The fix will be in a future release
    //       (see https://bugzilla.gnome.org/show_bug.cgi?id=724332).
    search_entry.set_size_request(600, -1);
    search_entry.margin = 4;
    header_bar.custom_title = search_entry;

    search_entry.changed.connect(() => {
      command_list.set_filter(search_entry.text);
      command_list.select_first_item();
    });

    search_entry.activate.connect(() => {
      var command = command_list.get_selected_command();
      if (command != null) {
        destroy();
        command.execute();
      }
    });
    command_list.row_activated.connect(() => search_entry.activate());

    add_events(Gdk.EventMask.FOCUS_CHANGE_MASK);
    focus_out_event.connect(() => {
      destroy();
      return true;
    });

    add_events(Gdk.EventMask.KEY_PRESS_MASK);
    key_press_event.connect((event) => {
      if (event.keyval == Gdk.Key.Escape) {
        destroy();
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

    show.connect(() => {
      search_entry.grab_focus();
    });
  }

}
