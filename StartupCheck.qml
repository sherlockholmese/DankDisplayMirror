import QtQuick
import qs.Common

QtObject {
    function check(done) {
        Proc.runCommand("dankDisplayMirror.dependencyCheck", ["sh", "-c", "command -v wl-mirror >/dev/null && command -v dms >/dev/null"], (stdout, exitCode) => {
            if (exitCode === 0) {
                done(null);
                return;
            }

            done({
                "title": I18n.trFor("dankDisplayMirror", "wl-mirror is required"),
                "details": I18n.trFor("dankDisplayMirror", "Install wl-mirror and make sure both wl-mirror and dms are available on PATH, then enable this plugin again.")
            });
        }, 0, 5000);
    }
}
