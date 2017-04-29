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

class Plotinus.InstanceSettings : Object {

  private Settings base_settings;
  private Settings instance_settings;

  public InstanceSettings(string schema_id, string base_name, string instance_name) {
    var schema_path = "/" + schema_id.replace(".", "/") + "/";

    base_settings = new Settings.with_path(schema_id, schema_path + base_name + "/");
    instance_settings = new Settings.with_path(schema_id, schema_path + instance_name + "/");
  }

  // Returns the value from instance_settings if it has been set there
  // and falls back to base_settings otherwise
  public Variant get_value(string key) {
    if (instance_settings.get_user_value(key) != null) {
      return instance_settings.get_value(key);
    } else {
      return base_settings.get_value(key);
    }
  }

}
