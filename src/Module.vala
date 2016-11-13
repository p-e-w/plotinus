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

// The module shares its global namespace with the host application,
// so all code should reside in a private namespace
namespace Plotinus {

  // Global reference to prevent destruction
  Plotinus plotinus;

  // Method signature adapted from https://github.com/gnome-globalmenu/gnome-globalmenu
  [CCode(cname="gtk_module_init")]
  public void gtk_module_init([CCode(array_length_pos=0.9)] ref unowned string[] argv) {
    Gtk.init(ref argv);

    Timeout.add(100, () => {
      var application = Application.get_default() as Gtk.Application;
      if (application != null) {
        plotinus = new Plotinus(application);
        plotinus.set_hotkeys({"<Primary><Shift>P"});
        return false;
      }
      return true;
    });
  }

}
