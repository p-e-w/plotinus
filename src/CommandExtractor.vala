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

class Plotinus.CommandExtractor : Object {

  private Gtk.Application? application;
  private string? application_name;

  private Gtk.Window window;

  public CommandExtractor() {
    application = null;
    application_name = null;
  }

  public CommandExtractor.with_application(Gtk.Application application, string application_name) {
    this.application = application;
    this.application_name = application_name;
  }

  public Command[] get_window_commands(Gtk.Window window) {
    Command[] commands = {};

    this.window = window;

    if (application != null && application.app_menu != null) {
      foreach (var command in get_menu_model_commands(application.app_menu, {application_name})) {
        commands += command;
      }
    }

    if (application != null && application.menubar != null) {
      foreach (var command in get_menu_model_commands(application.menubar, {})) {
        commands += command;
      }
    } else {
      var menu_bar = find_widget(window, typeof(Gtk.MenuBar)) as Gtk.MenuBar;
      if (menu_bar != null) {
        foreach (var command in get_menu_shell_commands(menu_bar, {})) {
          commands += command;
        }
      }
    }

    var titlebar = window.get_titlebar() as Gtk.Container;
    if (titlebar != null) {
      var window_title = get_window_title(window) ?? "Window";
      foreach (var command in get_container_commands(titlebar, {window_title}, true)) {
        commands += command;
      }
    }

    return commands;
  }

  private Command[] get_menu_model_commands(MenuModel menu_model, string[] path) {
    Command[] commands = {};

    for (var i = 0; i < menu_model.get_n_items(); i++) {
      var label_value = menu_model.get_item_attribute_value(i, Menu.ATTRIBUTE_LABEL, VariantType.STRING);
      var label = (label_value != null) ? clean_label(label_value.get_string()) : null;
      var action_value = menu_model.get_item_attribute_value(i, Menu.ATTRIBUTE_ACTION, VariantType.STRING);
      var action_name = (action_value != null) ? action_value.get_string() : null;
      var action = (action_name != null) ? get_action(action_name) : null;

      if (label != null && label != "" && action != null && action.enabled) {
        var accelerators = (application != null) ? application.get_accels_for_action(action_name) : new string[0];
        var target = menu_model.get_item_attribute_value(i, Menu.ATTRIBUTE_TARGET, null);
        commands += new ActionCommand(path, label, accelerators, action, target);
      }

      var link_iterator = menu_model.iterate_item_links(i);
      string link;
      MenuModel submenu_model;

      while (link_iterator.get_next(out link, out submenu_model)) {
        // Slicing the array creates a copy
        var submenu_path = path[0:path.length];
        if (label != null && label != "" && link == Menu.LINK_SUBMENU)
          submenu_path += label;
        foreach (var command in get_menu_model_commands(submenu_model, submenu_path)) {
          commands += command;
        }
      }
    }

    return commands;
  }

  private Action? get_action(string action_name) {
    var name_parts = action_name.split(".");

    if (name_parts.length == 2) {
      ActionMap action_map = null;

      if (name_parts[0] == "app") {
        action_map = application;
      } else if (name_parts[0] == "win" && window is ActionMap) {
        action_map = window as ActionMap;
      } else {
        action_map = window.get_action_group(name_parts[0]) as ActionMap;
      }

      if (action_map != null)
        return action_map.lookup_action(name_parts[1]);
    }

    return null;
  }

  private Command[] get_menu_shell_commands(Gtk.MenuShell menu_shell, string[] path) {
    Command[] commands = {};

    menu_shell.foreach((widget) => {
      if (!widget.is_sensitive() || !widget.get_visible())
        return;

      // Even *reading* a SeparatorMenuItem's label changes the item's appearance (GTK+ bug?),
      // so SeparatorMenuItems are skipped entirely
      if (widget is Gtk.MenuItem && !(widget is Gtk.SeparatorMenuItem)) {
        var menu_item = widget as Gtk.MenuItem;

        var label = (menu_item.label != null) ? clean_label(menu_item.label) : null;

        if (menu_item.submenu == null) {
          if (label != null && label != "") {
            string[] accelerators = {};
            if (menu_item.accel_path != null) {
              Gtk.AccelKey accel_key;
              if (Gtk.AccelMap.lookup_entry(menu_item.accel_path, out accel_key))
                accelerators += Gtk.accelerator_name(accel_key.accel_key, accel_key.accel_mods);
            } else if (menu_item.get_type().name() == "GtkModelMenuItem") {
              // ModelMenuItem is not part of GTK+'s public API, so we use GObject directly
              // to access the "accel" property holding the accelerator
              string? accelerator = null;
              menu_item.get("accel", out accelerator);
              if (accelerator != null && accelerator != "")
                accelerators += accelerator;
            }
            commands += new MenuItemCommand(path, label, accelerators, menu_item);
          }

        } else {
          // Slicing the array creates a copy
          var submenu_path = path[0:path.length];
          if (label != null && label != "")
            submenu_path += label;
          foreach (var command in get_menu_shell_commands(menu_item.submenu, submenu_path)) {
            commands += command;
          }
        }
      }
    });

    return commands;
  }

  private Command[] get_container_commands(Gtk.Container container, string[] path, bool strict_visibility_check) {
    Command[] commands = {};

    container.foreach((widget) => {
      if (!widget.is_sensitive() || !widget.get_visible() || (strict_visibility_check && !widget.is_visible()))
        return;

      if (widget is Gtk.Button) {
        var button = widget as Gtk.Button;
        var label = get_button_label(button);

        if (button is Gtk.MenuButton) {
          var menu_button = button as Gtk.MenuButton;

          // Slicing the array creates a copy
          var submenu_path = path[0:path.length];
          // Do not add main menu button label to path (actions are associated directly with the window)
          if (label != null && label != "" && !/^(menu|gear|action)$/i.match(label))
            submenu_path += label;

          if (menu_button.menu_model != null) {
            foreach (var command in get_menu_model_commands(menu_button.menu_model, submenu_path)) {
              commands += command;
            }
          } else if (menu_button.popup != null) {
            foreach (var command in get_menu_shell_commands(menu_button.popup, submenu_path)) {
              commands += command;
            }
          } else if (menu_button.popover != null) {
            // Disable strict (ancestors) visibility check so that buttons in popover can be found
            foreach (var command in get_container_commands(menu_button.popover, submenu_path, false)) {
              commands += command;
            }
          }

        } else if (label != null && label != "") {
          var accelerators = (application != null && button.action_name != null) ?
              application.get_accels_for_action(button.action_name) : new string[0];
          commands += new ButtonCommand(path, label, accelerators, button);
        }

      } else if (widget is Gtk.Container) {
        foreach (var command in get_container_commands(widget as Gtk.Container, path, strict_visibility_check)) {
          commands += command;
        }
      }
    });

    return commands;
  }

}
