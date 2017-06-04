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

using Plotinus.Utilities;

namespace Plotinus {

  interface Keybinder : Object {
    public abstract void set_keys(string[] keys);
    public signal void keys_pressed(Gtk.Window window);
  }

  class ApplicationKeybinder : Object, Keybinder {
    private const string ACTION_NAME = "activate-plotinus";

    private Gtk.Application application;

    public ApplicationKeybinder(Gtk.Application application) {
      this.application = application;

      var action = new SimpleAction(ACTION_NAME, null);

      action.activate.connect(() => {
        if (application.active_window != null)
          keys_pressed(application.active_window);
      });

      application.add_action(action);
    }

    public void set_keys(string[] keys) {
      application.set_accels_for_action("app." + ACTION_NAME, keys);
    }
  }

  class WindowKeybinder : Object, Keybinder {
    private struct Key {
      public uint key;
      public Gdk.ModifierType modifiers;
    }

    private Key[] parsed_keys = {};

    public WindowKeybinder() {
      ulong[] handler_ids = {};

      Timeout.add(SCAN_INTERVAL, () => {
        foreach (var window in get_windows()) {
          bool handler_installed = false;
          foreach (var handler_id in handler_ids) {
            if (SignalHandler.is_connected(window, handler_id)) {
              handler_installed = true;
              break;
            }
          }

          if (handler_installed)
            continue;

          window.add_events(Gdk.EventMask.KEY_PRESS_MASK);
          handler_ids += window.key_press_event.connect((event) => {
            foreach (var parsed_key in parsed_keys) {
              if (Gdk.keyval_to_lower(event.keyval) == parsed_key.key && event.state == parsed_key.modifiers) {
                keys_pressed(window);
                return true;
              }
            }

            return false;
          });
        }

        return true;
      });
    }

    public void set_keys(string[] keys) {
      parsed_keys = {};

      foreach (var key in keys) {
        var parsed_key = Key();
        Gtk.accelerator_parse(key, out parsed_key.key, out parsed_key.modifiers);
        parsed_keys += parsed_key;
      }
    }
  }

}
