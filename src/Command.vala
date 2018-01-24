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

    [DBus(visible=false)]
    public virtual bool set_image(Gtk.CellRendererPixbuf cell) {
      return false;
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
    private Variant? icon;

    public ActionCommand(string[] path, string label, string[] accelerators, Action action, Variant? parameter, Variant? icon) {
      base(path, label, accelerators);
      this.action = action;
      this.parameter = parameter;
      this.icon = icon;
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
      if(parameter != null && action.get_state() != null)
        return Gtk.ButtonRole.RADIO;

      if(action.get_state_type() != null && VariantType.BOOLEAN.equal(action.get_state_type()))
        return Gtk.ButtonRole.CHECK;

      return Gtk.ButtonRole.NORMAL;
    }

    public override bool set_image(Gtk.CellRendererPixbuf cell) {
      if(this.icon == null)
        return base.set_image(cell);

      var icon = Icon.deserialize(this.icon);
      cell.gicon = icon;
      return true;
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

    public override bool set_image(Gtk.CellRendererPixbuf cell) {
      if(!(menu_item is Gtk.ImageMenuItem))
        return base.set_image(cell);

      var image_menu_item = menu_item as Gtk.ImageMenuItem;
      if(!(image_menu_item.always_show_image || Gtk.Settings.get_default().gtk_menu_images))
        return base.set_image(cell);

      var widget = image_menu_item.get_image();
      if(!(widget is Gtk.Image))
        return base.set_image(cell);

      var image = widget as Gtk.Image;

      cell.stock_size = Gtk.IconSize.MENU;

      switch(image.get_storage_type()) {
        case Gtk.ImageType.PIXBUF:
          cell.pixbuf = image.pixbuf;
          return true;
        case Gtk.ImageType.ICON_NAME:
          cell.icon_name = image.icon_name;
          return true;
        case Gtk.ImageType.GICON:
          cell.gicon = image.gicon;
          return true;
        case Gtk.ImageType.STOCK:
          cell.stock_id = image.stock;
          return true;
        default:
          return base.set_image(cell);
      }
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
