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

  abstract class Command : Object {
    private static int next_id = 0;

    public int id { get; private set; }
    public string[] path { get; private set; }
    public string label { get; private set; }
    public string[] accelerators { get; private set; }

    public abstract void execute();

    protected Command(string[] path, string label, string[] accelerators) {
      id = next_id++;
      this.path = path;
      this.label = label;
      this.accelerators = accelerators;
    }
  }

  class ActionCommand : Command {
    private Action action;

    public override void execute() {
      action.activate(null);
    }

    public ActionCommand(string[] path, string label, string[] accelerators, Action action) {
      base(path, label, accelerators);
      this.action = action;
    }
  }

  class MenuItemCommand : Command {
    private Gtk.MenuItem menu_item;

    public override void execute() {
      menu_item.activate();
    }

    public MenuItemCommand(string[] path, string label, string[] accelerators, Gtk.MenuItem menu_item) {
      base(path, label, accelerators);
      this.menu_item = menu_item;
    }
  }

  class ButtonCommand : Command {
    private Gtk.Button button;

    public override void execute() {
      button.clicked();
    }

    public ButtonCommand(string[] path, string label, string[] accelerators, Gtk.Button button) {
      base(path, label, accelerators);
      this.button = button;
    }
  }

}
