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

class Plotinus.CommandList : Gtk.TreeView {

  private class ListColumn : Gtk.TreeViewColumn {
    public delegate string MarkupFunction(Command command);

    public ListColumn(MarkupFunction markup_function, bool align_right, Gdk.RGBA? text_color, double font_scale = 1) {
      var cell_renderer = new Gtk.CellRendererText();
      if (align_right)
        cell_renderer.xalign = 1;
      if (text_color != null)
        cell_renderer.foreground_rgba = text_color;
      cell_renderer.scale = font_scale;

      pack_start(cell_renderer, true);

      set_cell_data_func(cell_renderer, (cell_layout, cell, tree_model, tree_iter) => {
        (cell as Gtk.CellRendererText).markup = markup_function(get_iter_command(tree_model, tree_iter));
      });
    }
  }

  private string filter = "";
  private string[] filter_words = {};

  private Gtk.TreeModelFilter tree_model_filter;
  private Gtk.TreeModelSort tree_model_sort;

  public CommandList(Command[] commands) {
    var list_store = new Gtk.ListStore(1, typeof(Command));

    foreach (var command in commands) {
      Gtk.TreeIter tree_iter;
      list_store.append(out tree_iter);
      list_store.set_value(tree_iter, 0, command);
    }

    tree_model_filter = new Gtk.TreeModelFilter(list_store, null);
    tree_model_filter.set_visible_func((tree_model, tree_iter) => {
      if (filter == "")
        return true;
      return get_command_score(get_iter_command(tree_model, tree_iter)) >= 0;
    });

    tree_model_sort = new Gtk.TreeModelSort.with_model(tree_model_filter);
    model = tree_model_sort;

    headers_visible = false;

    // The theme's style context is reliably available only after the widget has been realized
    realize.connect(() => {
      var style_context = get_style_context();
      var text_color = style_context.get_color(Gtk.StateFlags.NORMAL);
      var selection_color = style_context.get_background_color(Gtk.StateFlags.SELECTED | Gtk.StateFlags.FOCUSED);

      text_color.alpha = 0.4;
      append_column(new ListColumn((command) => {
        return highlight_words(string.joinv("  \u25B6  ", command.path), filter_words) + "  ";
      }, true, text_color));

      append_column(new ListColumn((command) => {
        return highlight_words(command.label, filter_words);
      }, false, null, 1.4));

      append_column(new ListColumn((command) => {
        return Markup.escape_text(string.joinv(", ", map_string(command.accelerators, format_accelerator)));
      }, true, selection_color));
    });
  }

  public void set_filter(string filter) {
    // Preprocess filter string to simplify search
    this.filter = /\s{2,}/.replace(filter, -1, 0, " ").strip().casefold();
    filter_words = this.filter.split(" ");

    tree_model_filter.refilter();

    // TreeModelSort has no "resort" method, but reassigning the comparison function forces a resort
    tree_model_sort.set_default_sort_func((tree_model, tree_iter_a, tree_iter_b) => {
      var command_a = get_iter_command(tree_model, tree_iter_a);
      var command_b = get_iter_command(tree_model, tree_iter_b);

      // "The sort function used by TreeModelSort is not guaranteed to be stable" (GTK+ documentation),
      // so the original order of commands is needed as a tie-breaker
      var id_difference = command_a.id - command_b.id;

      if (this.filter == "")
        return id_difference;

      var score_difference = get_command_score(command_a) - get_command_score(command_b);
      return (score_difference != 0) ? score_difference : id_difference;
    });
  }

  // Returns a score indicating how closely the command matches the filter.
  // The lower the score, the better the match. A negative score means no match.
  private int get_command_score(Command command) {
    var label = command.label.casefold();
    var path = string.joinv(" ", command.path).casefold();

    int score = 0;

    if (label.has_prefix(filter))
      return score;

    score++;

    if (label.contains(filter))
      return score;

    score++;

    if (contains_words(label, filter_words))
      return score;

    score++;

    if (contains_words(label, filter_words, false))
      return score;

    score++;

    if (contains_words(path, filter_words))
      return score;

    score++;

    if (contains_words(path, filter_words, false))
      return score;

    return -1;
  }

  public Command? get_selected_command() {
    var selected_iter = get_selected_iter();
    if (selected_iter != null) {
      return get_iter_command(model, selected_iter);
    } else {
      return null;
    }
  }

  public void select_first_item() {
    Gtk.TreeIter first_iter;
    if (model.get_iter_first(out first_iter)) {
      get_selection().select_iter(first_iter);
      scroll_to_selected_item();
    }
  }

  public void select_previous_item() {
    var selected_iter = get_selected_iter();
    if (selected_iter != null && model.iter_previous(ref selected_iter)) {
      get_selection().select_iter(selected_iter);
      scroll_to_selected_item();
    }
  }

  public void select_next_item() {
    var selected_iter = get_selected_iter();
    if (selected_iter != null && model.iter_next(ref selected_iter)) {
      get_selection().select_iter(selected_iter);
      scroll_to_selected_item();
    }
  }

  private Gtk.TreeIter? get_selected_iter() {
    Gtk.TreeModel tree_model;
    Gtk.TreeIter selected_iter;
    if (get_selection().get_selected(out tree_model, out selected_iter)) {
      return selected_iter;
    } else {
      return null;
    }
  }

  private static Command get_iter_command(Gtk.TreeModel tree_model, Gtk.TreeIter tree_iter) {
    Value command;
    tree_model.get_value(tree_iter, 0, out command);
    return (Command) command;
  }

  private void scroll_to_selected_item() {
    var selected_iter = get_selected_iter();
    if (selected_iter != null) {
      var selected_path = model.get_path(selected_iter);
      scroll_to_cell(selected_path, null, false, 0, 0);
    }
  }

}
