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

    public virtual bool is_active() {
      return false;
    }

    public virtual Gtk.ButtonRole get_check_type() {
      return Gtk.ButtonRole.NORMAL;
    }
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

    public override bool is_active() {
      switch(get_check_type()) {
        case Gtk.ButtonRole.RADIO:
          return parameter.equal(action.get_state());
        case Gtk.ButtonRole.CHECK:
          return action.get_state().get_boolean();
        default:
          return false;
      }
    }

    public override Gtk.ButtonRole get_check_type() {
      if(parameter != null)
        return Gtk.ButtonRole.RADIO;

      if(action.get_state_type() != null && VariantType.BOOLEAN.equal(action.get_state_type()))
        return Gtk.ButtonRole.CHECK;

      return Gtk.ButtonRole.NORMAL;
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

    public override bool is_active() {
      if(get_check_type() != Gtk.ButtonRole.NORMAL)
        return (menu_item as Gtk.CheckMenuItem).active;

      return false;
    }
    public override Gtk.ButtonRole get_check_type() {
      if(menu_item is Gtk.CheckMenuItem) {
        var checkable = menu_item as Gtk.CheckMenuItem;
        if((menu_item is Gtk.RadioMenuItem) || checkable.draw_as_radio)
          return Gtk.ButtonRole.RADIO;

        return Gtk.ButtonRole.CHECK;
      }

      return Gtk.ButtonRole.NORMAL;
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

    public override bool is_active() {
      if(get_check_type() != Gtk.ButtonRole.NORMAL)
        return (button as Gtk.CheckButton).active;

      return false;
    }

    public override Gtk.ButtonRole get_check_type() {
      if(button is Gtk.RadioButton)
        return Gtk.ButtonRole.RADIO;

      if(button is Gtk.CheckButton)
        return Gtk.ButtonRole.CHECK;

      return Gtk.ButtonRole.NORMAL;
    }
  }

}
