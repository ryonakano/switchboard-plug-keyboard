/*
 * SPDX-License-Identifier: GPL-2.0-or-later
 * SPDX-FileCopyrightText: 2017-2023 elementary, Inc. (https://elementary.io)
 */

 class Keyboard.Shortcuts.ConflictsManager : GLib.Object {
    public static bool shortcut_conflicts (Shortcut shortcut, out string name, out string group) {
        name = "";
        group = SectionID.SYSTEM.to_string ();
        return general_shortcut_conflicts (shortcut, out name, out group) || custom_shortcut_conflicts (shortcut, out name, out group);
    }

    private static bool general_shortcut_conflicts (Shortcut shortcut, out string name, out string group) {
        unowned var list = ShortcutsList.get_default ();

        for (int group_id = 0; group_id < SectionID.CUSTOM; group_id++) {
            string[] actions, keys;
            Schema[] schemas;

            name = "";
            group = ((SectionID) group_id).to_string ();
            list.get_group (group_id, out actions, out schemas, out keys);

            // For every action in group there is a corresponding schema and key entry
            // so only need to iterate actions
            for (int i = 0; i < actions.length; i++) {
                var action_shortcut = Settings.get_default ().get_val (schemas[i], keys[i]);
                if (shortcut.is_equal (action_shortcut)) {
                    name = actions[i];
                    return true;
                }
            }
        }

        name = "";
        group = SectionID.SYSTEM.to_string ();
        return false;
    }

    private static bool custom_shortcut_conflicts (Shortcut shortcut, out string name, out string group) {
        name = "";
        group = SectionID.CUSTOM.to_string ();
        return CustomShortcutSettings.shortcut_conflicts (shortcut, out name, null);
    }
}
