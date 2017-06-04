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

  [DBus(name="com.worldwidemann.plotinus.Command")]
  abstract class Command : Object {
    private static int next_id = 0;

    public int id { get; private set; }
    public string[] path { get; private set; }
    public string label { get; private set; }
    public string[] accelerators { get; private set; }

    protected Command(string[] path, string label, string[] accelerators) {
      id = next_id++;
      this.path = path;
      this.label = label;
      this.accelerators = accelerators;
    }

    public abstract void execute();
  }

  class SignalCommand : Command {
    public SignalCommand(string[] path, string label, string[] accelerators) {
      base(path, label, accelerators);
    }

    public override void execute() {
      executed();
    }

    public signal void executed();
  }

  class ActionCommand : Command {
    private Action action;
    private Variant? parameter;

    public ActionCommand(string[] path, string label, string[] accelerators, Action action, Variant? parameter) {
      base(path, label, accelerators);
      this.action = action;
      this.parameter = parameter;
    }

    public override void execute() {
      action.activate(parameter);
    }
  }

  class MenuItemCommand : Command {
    private Gtk.MenuItem menu_item;

    public MenuItemCommand(string[] path, string label, string[] accelerators, Gtk.MenuItem menu_item) {
      base(path, label, accelerators);
      this.menu_item = menu_item;
    }

    public override void execute() {
      menu_item.activate();
    }
  }

  class ButtonCommand : Command {
    private Gtk.Button button;

    public ButtonCommand(string[] path, string label, string[] accelerators, Gtk.Button button) {
      base(path, label, accelerators);
      this.button = button;
    }

    public override void execute() {
      button.clicked();
    }
  }

}
