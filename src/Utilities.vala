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

namespace Plotinus.Utilities {

  delegate string MapFunction(string element);

  // A generic version of this is possible,
  // but generates a lot of compiler warnings
  string[] map_string(string[] array, MapFunction map_function) {
    string[] result = {};
    foreach (var element in array) {
      result += map_function(element);
    }
    return result;
  }

  bool contains_words(string text, string[] words, bool require_all = true) {
    foreach (var word in words) {
      if (text.contains(word)) {
        if (!require_all)
          return true;
      } else if (require_all) {
        return false;
      }
    }

    return require_all;
  }

  // Returns a version of text in which all occurrences of words
  // are highlighted using Pango markup
  string highlight_words(string text, string[] words, string markup_tag = "b") {
    if (words.length == 0)
      return Markup.escape_text(text);

    var regex_words = map_string(words, (word) => { return Regex.escape_string(word); });
    // Build a regular expression of the form "(word1|word2|...)", matching any of the words.
    // The outer parentheses also define a capturing group, which is important (see below).
    var regex = new Regex("(" + string.joinv("|", regex_words) + ")", RegexCompileFlags.CASELESS);

    var builder = new StringBuilder();

    // Regex.split also returns capturing group matches from the "delimiter",
    // and since the entire pattern is a capturing group, the result is all of the text,
    // split into matches and non-matches of words
    foreach (var part in regex.split(text)) {
      var part_markup = Markup.escape_text(part);

      // Note that while Regex.match looks for matches anywhere within a string,
      // partial matches cannot occur here because the parts are already split
      // along pattern boundaries
      if (regex.match(part)) {
        builder.append("<").append(markup_tag).append(">");
        builder.append(part_markup);
        builder.append("</").append(markup_tag).append(">");
      } else {
        builder.append(part_markup);
      }
    }

    return builder.str;
  }

  string format_accelerator(string accelerator) {
    uint key;
    Gdk.ModifierType modifiers;
    Gtk.accelerator_parse(accelerator, out key, out modifiers);
    return Gtk.accelerator_get_label(key, modifiers);
  }

  string clean_label(string label) {
    // Remove underscores not followed by another underscore (mnemonic prefixes)
    return /_(?!_)/.replace(label, -1, 0, "").strip();
  }

  Gtk.Widget? find_widget(Gtk.Container container, Type widget_type) {
    var widgets = container.get_children();

    for (var i = 0; i < widgets.length(); i++) {
      var widget = widgets.nth_data(i);

      if (!widget.get_visible())
        continue;

      if (widget.get_type().is_a(widget_type)) {
        return widget;
      } else if (widget is Gtk.Container) {
        var inner_widget = find_widget(widget as Gtk.Container, widget_type);
        if (inner_widget != null)
          return inner_widget;
      }
    }

    return null;
  }

  string? get_button_label(Gtk.Button button) {
    if (button.label != null)
      return clean_label(button.label);

    var label = find_widget(button, typeof(Gtk.Label)) as Gtk.Label;
    if (label != null)
      return label.get_text();

    if (button.tooltip_text != null)
      return button.tooltip_text;

    var name = button.get_name();
    if (name != null) {
      // Parse a widely used GtkBuilder naming convention (name_button)
      var name_parts = name.split("_");
      if (name_parts.length > 1 && name_parts[name_parts.length - 1] == "button") {
        for (var i = 0; i < name_parts.length - 1; i++) {
          if (name_parts[i].length > 1)
            // Capitalize word
            name_parts[i] = name_parts[i].substring(0, 1).up() + name_parts[i].substring(1);
        }
        return string.joinv(" ", name_parts[0:name_parts.length - 1]);
      }
    }

    return null;
  }

  string? get_window_title(Gtk.Window window) {
    var titlebar = window.get_titlebar();
    if (titlebar == null)
      return window.title;

    Gtk.HeaderBar header_bar = titlebar as Gtk.HeaderBar;
    if (header_bar == null && titlebar is Gtk.Container)
      // Some applications nest the header bar inside another widget, such as a Gtk.Paned
      header_bar = find_widget(titlebar as Gtk.Container, typeof(Gtk.HeaderBar)) as Gtk.HeaderBar;

    if (header_bar != null && header_bar.custom_title == null && header_bar.title != null)
      return header_bar.title;

    return window.title;
  }

}
