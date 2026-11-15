#!/usr/bin/python3
"""End-to-end flow: real app + real root helper, with fake sudo/systemctl (see run-tests.sh).

Checks that helper calls never block the main loop, and that toggling, editing,
applying and reopening the window behave as expected.
"""
import os
import pathlib
import runpy
import sys
import time
from types import SimpleNamespace

APP = SimpleNamespace(**runpy.run_path(
    str(pathlib.Path(__file__).resolve().parents[1] / "src" / "zapret-sites-gui"), run_name="zapret_sites_gui"
))
from gi.repository import GLib  # noqa: E402

CALLS = pathlib.Path(os.environ.get("FAKE_SYSTEMD_DIR", "/tmp/fake-systemd")) / "calls.log"
TIMEOUT_S = 30


class FlowApp(APP.App):
    def __init__(self):
        super().__init__()
        self.failures = []
        self.ticks = 0
        self.steps = self.scenario()

    def start_tray(self):
        pass

    def do_activate(self):
        super().do_activate()
        if not hasattr(self, "started"):
            self.started = time.monotonic()
            GLib.timeout_add(50, self.tick)
            GLib.timeout_add(20, self.drive)

    def tick(self):
        self.ticks += 1
        return GLib.SOURCE_CONTINUE

    def check(self, name, condition):
        print(("ok   " if condition else "FAIL ") + name, flush=True)
        if not condition:
            self.failures.append(name)

    def drive(self):
        if time.monotonic() - self.started > TIMEOUT_S:
            self.failures.append("timed out")
            self.quit_app()
            return GLib.SOURCE_REMOVE
        if getattr(self, "waiting", None) and not self.waiting():
            return GLib.SOURCE_CONTINUE
        try:
            self.waiting = next(self.steps)
        except StopIteration:
            self.quit_app()
            return GLib.SOURCE_REMOVE
        return GLib.SOURCE_CONTINUE

    def scenario(self):
        win = self.window
        yield lambda: self.status is not None
        self.check("initial status is read", self.status == {"zapret": "inactive", "dns": "inactive"})
        self.check("hero shows off", win.hero_title.get_label() == "Bypass kapalı")

        ticks = self.ticks
        win.switch.set_active(True)
        self.check("toggle marks the app busy", self.busy)
        self.check("switch stays at the requested position while busy", win.switch.get_active())
        yield lambda: not self.busy
        self.check("main loop kept running during the 1 s helper call", self.ticks - ticks >= 10)
        self.check("bypass is on", self.active and win.hero_title.get_label() == "Bypass açık")
        self.check("both services were started", "start zapret-dns" in CALLS.read_text()
                   and "start zapret" in CALLS.read_text())

        win.entry.set_text("Wattpad.com ")
        win.on_add_domain(win.entry)
        self.check("entry adds a normalized domain", self.draft[-1] == "wattpad.com")
        self.check("apply bar is revealed", win.toolbar.get_reveal_bottom_bars())
        self.check("apply action is enabled", self.lookup_action("apply").get_enabled())

        win.entry.set_text("bad domain")
        win.on_add_domain(win.entry)
        self.check("invalid entry is rejected", "bad domain" not in self.draft
                   and win.entry.has_css_class("error"))

        CALLS.write_text("")
        self.activate_action("apply")
        yield lambda: not self.busy
        listed = pathlib.Path(APP.LIST).read_text().split()
        self.check("list file holds the draft", listed == self.draft and "wattpad.com" in listed)
        calls = CALLS.read_text()
        self.check("apply re-applies DNS domains only", "dns-setup domains" in calls)
        self.check("apply does not restart zapret", "start zapret" not in calls and "stop zapret" not in calls)
        self.check("apply bar hides after apply", not win.toolbar.get_reveal_bottom_bars())

        win.preset_rows["Telegram"].set_active(True)
        self.check("preset adds its domains", set(APP.PRESETS["Telegram"]) <= set(self.draft))
        self.activate_action("revert")
        self.check("revert restores the saved list", self.draft == self.saved)
        self.check("preset switch follows revert", not win.preset_rows["Telegram"].get_active())

        self.hide_window()
        self.check("hiding destroys the window", self.window is None)
        self.activate()
        self.check("reopening builds a new window", self.window is not None and self.window is not win)
        win = self.window

        win.switch.set_active(False)
        yield lambda: not self.busy
        self.check("bypass is off", not self.active and win.hero_title.get_label() == "Bypass kapalı")


if __name__ == "__main__":
    app = FlowApp()
    app.run([sys.argv[0]])
    print("FAILED: " + ", ".join(app.failures) if app.failures else "all flow checks passed")
    sys.exit(1 if app.failures else 0)
