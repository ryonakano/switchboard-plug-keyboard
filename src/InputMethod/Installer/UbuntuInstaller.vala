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

public class Pantheon.Keyboard.InputMethodPage.UbuntuInstaller : Object {
    private AptdProxy aptd;
    private AptdTransactionProxy proxy;

    public bool can_cancel { get; private set; }
    private Cancellable? cancellable = null;
    public TransactionMode transaction_mode { get; private set; }
    public string engine_to_address { get; private set; }

    public signal void install_finished ();
    public signal void install_failed ();
    public signal void remove_finished (string langcode);
    public signal void progress_changed (int progress);

    public enum TransactionMode {
        INSTALL,
        REMOVE,
        INSTALL_MISSING,
    }

    Gee.HashMap<string, string> transactions;

    private static GLib.Once<UbuntuInstaller> instance;
    public static unowned UbuntuInstaller get_default () {
        return instance.once (() => {
            return new UbuntuInstaller ();
        });
    }

    private UbuntuInstaller () {}

    construct {
        transactions = new Gee.HashMap<string, string> ();
        aptd = new AptdProxy ();

        try {
            aptd.connect_to_aptd ();
        } catch (Error e) {
            warning ("Could not connect to APT daemon");
        }
    }

    public void install (string engine_name) {
        transaction_mode = TransactionMode.INSTALL;
        engine_to_address = engine_name;
        string[] packages = {};
        packages += engine_to_address;
        cancellable = new Cancellable ();

        foreach (var packet in packages) {
            message ("Packet: %s", packet);
        }

        Pk.Results result;
        var task = new Pk.Task ();

        // Resolve the package name
        try {
            result = task.resolve_sync (Pk.Filter.NOT_INSTALLED, packages, cancellable, ((process, type) => {}));
        } catch (Error e) {
            warning ("Could not resolve packages: %s", e.message);
            on_failed ();
            return;
        }

        // Get the packages id
        string[] package_ids = {};
        var package_array = result.get_package_array ();
        package_array.foreach ((package) => {
            package_ids += package.get_id ();
        });

        // Install packages
        task.install_packages_async.begin (package_ids, cancellable, progress_callback, ((obj, res) => {
            try {
                result = task.install_packages_async.end (res);
            } catch (Error e) {
                warning ("Failed to install packages: %s", e.message);
                on_failed ();
                return;
            }

            Pk.Error err = result.get_error_code ();
            if (err != null) {
                warning ("Error while installing packages: %s, %s", err.code.to_string (), err.details);
                on_failed ();
                return;
            }
        }));

//        aptd.install_packages.begin (packages, (obj, res) => {
//            try {
//                var transaction_id = aptd.install_packages.end (res);
//                transactions.@set (transaction_id, "i-" + engine_name);
//                run_transaction (transaction_id);
//            } catch (Error e) {
//                warning ("Could not queue downloads: %s", e.message);
//            }
//        });
    }

    public void cancel_install () {
        if (cancellable != null && can_cancel) {
            warning ("cancel_install");
            cancellable.cancel ();
        }
    }

    private void progress_callback (Pk.Progress progress, Pk.ProgressType type) {
        switch (type) {
            case Pk.ProgressType.STATUS:
                if (progress.status == Pk.Status.FINISHED) {
                    on_finished ();
                }

                break;
            case Pk.ProgressType.PERCENTAGE:
                progress_changed (progress.percentage);
                break;
            case Pk.ProgressType.ALLOW_CANCEL:
                can_cancel = progress.allow_cancel;
                break;
            default:
                break;
        }
    }

    private void on_finished () {
        cancellable = null;
        install_finished ();
    }

    private void on_failed () {
        cancellable = null;
        install_failed ();
    }

    private void run_transaction (string transaction_id) {
        proxy = new AptdTransactionProxy ();
        proxy.finished.connect (() => {
            on_apt_finshed (transaction_id, true);
        });

        proxy.property_changed.connect ((prop, val) => {
            if (prop == "Progress") {
                progress_changed ((int) val.get_int32 ());
            }

            if (prop == "Cancellable") {
//                install_cancellable = val.get_boolean ();
                can_cancel = val.get_boolean ();
            }
        });

        try {
            proxy.connect_to_aptd (transaction_id);
            proxy.simulate ();

            proxy.run ();
        } catch (Error e) {
            on_apt_finshed (transaction_id, false);
            warning ("Could no run transaction: %s", e.message);
        }
    }

    private void on_apt_finshed (string id, bool success) {
        if (!success) {
            install_failed ();
            transactions.unset (id);
            return;
        }

        if (!transactions.has_key (id)) { //transaction already removed
            return;
        }

        var action = transactions.get (id);
        var lang = action[2:action.length];

        message ("ID %s -> %s", id, success ? "success" : "failed");

        if (action[0:1] == "i") { // install
//            install_finished (lang);
            install_finished ();
        } else {
            remove_finished (lang);
        }

        transactions.unset (id);
    }
}
