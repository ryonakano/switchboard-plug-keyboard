/*
* Copyright 2011-2023 elementary, Inc. (https://elementary.io)
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
    public bool can_cancel { get; private set; }
    private Cancellable? cancellable = null;
    public TransactionMode transaction_mode { get; private set; }
    public string package { get; private set; }

    public signal void install_finished ();
    public signal void install_failed ();
    public signal void progress_changed (int progress);

    public enum TransactionMode {
        INSTALL,
        REMOVE,
        INSTALL_MISSING,
    }

    private static GLib.Once<UbuntuInstaller> instance;
    public static unowned UbuntuInstaller get_default () {
        return instance.once (() => {
            return new UbuntuInstaller ();
        });
    }

    private UbuntuInstaller () {}

    public void install (string pkg) {
        transaction_mode = TransactionMode.INSTALL;
        package = pkg;
        string[] packages = {};
        packages += package;
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
}
