/*
* Copyright 2011-2020 elementary, Inc. (https://elementary.io)
*
* This program is free software: you can redistribute it
* and/or modify it under the terms of the GNU Lesser General Public License as
* published by the Free Software Foundation, either version 3 of the
* License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be
* useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
* Public License for more details.
*
* You should have received a copy of the GNU General Public License along
* with this program. If not, see http://www.gnu.org/licenses/.
*/

public class Pantheon.Keyboard.InputMethodPage.ProgressDialog : Granite.Dialog {
    private Gtk.ProgressBar progress_bar;

    construct {
        var image = new Gtk.Image.from_icon_name ("preferences-desktop-locale", Gtk.IconSize.DIALOG) {
            valign = Gtk.Align.START
        };

        var primary_label = new Gtk.Label (null) {
            max_width_chars = 50,
            wrap = true,
            xalign = 0
        };
        primary_label.get_style_context ().add_class (Granite.STYLE_CLASS_PRIMARY_LABEL);

        unowned UbuntuInstaller installer = UbuntuInstaller.get_default ();
        switch (installer.transaction_mode) {
            case UbuntuInstaller.TransactionMode.INSTALL:
                primary_label.label = _("Installing %s").printf (installer.engine_to_address);
                break;
            case UbuntuInstaller.TransactionMode.REMOVE:
                primary_label.label = _("Removing %s").printf (installer.engine_to_address);
                break;
        }

        progress_bar = new Gtk.ProgressBar () {
            hexpand = true,
            valign = Gtk.Align.START,
            width_request = 300
        };

        var cancel_button = (Gtk.Button) add_button (_("Cancel"), 0);

        installer.bind_property ("can-cancel", cancel_button, "sensitive");

        var grid = new Gtk.Grid () {
            column_spacing = 12,
            margin = 6,
            row_spacing = 6
        };
        grid.attach (image, 0, 0, 1, 2);
        grid.attach (primary_label, 1, 0);
        grid.attach (progress_bar, 1, 1);
        grid.show_all ();

        border_width = 6;
        deletable = false;
        get_content_area ().add (grid);

        cancel_button.clicked.connect (() => {
            installer.cancel_install ();
            destroy ();
        });
    }

    public void set_progress (int progress) {
        progress_bar.fraction = progress;
    }
}
