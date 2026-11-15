#!/usr/bin/python3
"""Render the main window in fixed states to PNG files, headless, for visual review.

Run inside the test container:
  gtk4-broadwayd :5 & GDK_BACKEND=broadway BROADWAY_DISPLAY=:5 python3 tests/render-screenshots.py OUT_DIR
No root helper or tray is started; states are injected directly.
"""
import pathlib
import runpy
import sys
from types import SimpleNamespace

APP = SimpleNamespace(**runpy.run_path(
    str(pathlib.Path(__file__).resolve().parents[1] / "src" / "zapret-sites-gui"), run_name="zapret_sites_gui"
))
from gi.repository import Adw, Gdk, GLib, Graphene, Gtk  # noqa: E402

OUT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "screenshots")
SAVED = ["discord.gg", "discord.com", "discordapp.com", "wattpad.com", "example.org"]

SCENES = [
    # name, color scheme, status, busy, draft change, expanded
    ("on-light", Adw.ColorScheme.FORCE_LIGHT, {"zapret": "active", "dns": "active"}, False, None, False),
    ("on-dark", Adw.ColorScheme.FORCE_DARK, {"zapret": "active", "dns": "active"}, False, None, False),
    ("off-light", Adw.ColorScheme.FORCE_LIGHT, {"zapret": "inactive", "dns": "inactive"}, False, None, False),
    ("dirty-expanded-dark", Adw.ColorScheme.FORCE_DARK, {"zapret": "active", "dns": "active"}, False,
     "example.net", True),
    ("dns-down-light", Adw.ColorScheme.FORCE_LIGHT, {"zapret": "active", "dns": "inactive"}, False, None, False),
    ("busy-light", Adw.ColorScheme.FORCE_LIGHT, {"zapret": "inactive", "dns": "inactive"}, True, None, False),
    ("loading-dark", Adw.ColorScheme.FORCE_DARK, None, False, None, False),
]


class ShotApp(APP.App):
    def start_tray(self):
        pass

    def refresh_status(self):
        pass

    def do_activate(self):
        # Broadway leaves gtk-xft-dpi unset; a desktop session sets it, and libadwaita 1.5
        # sizes Adw.Clamp in sp units derived from it.
        Gtk.Settings.get_default().set_property("gtk-xft-dpi", 96 * 1024)
        self.scenes = list(SCENES)
        self.next_scene()

    def next_scene(self):
        if not self.scenes:
            self.quit_app()
            return
        name, scheme, status, busy, extra, expanded = self.scenes.pop(0)
        Adw.StyleManager.get_default().set_color_scheme(scheme)
        self.saved, self.draft = list(SAVED), list(SAVED) + ([extra] if extra else [])
        self.status, self.busy, self.target = status, busy, (True if busy else None)
        self.list_expanded = expanded
        if self.window is not None:
            self.window.destroy()
        self.window = APP.Window(self)
        self.window.set_default_size(560, 760)
        self.update()
        self.window.present()
        GLib.timeout_add(1000, self.capture, name)

    def capture(self, name):
        win = self.window
        width, height = win.get_width(), win.get_height()
        snapshot = Gtk.Snapshot()
        Gtk.WidgetPaintable.new(win).snapshot(snapshot, width, height)
        node = snapshot.to_node()
        if node is None:
            return GLib.SOURCE_CONTINUE  # not painted yet; try again
        texture = win.get_renderer().render_texture(node, Graphene.Rect().init(0, 0, width, height))
        data = Gdk.TextureDownloader.new(texture).download_bytes()[0].get_data()
        if len({data[i:i + 4] for i in range(0, len(data), 4 * 101)}) < 2:
            return GLib.SOURCE_CONTINUE  # nothing drawn yet (first window can lag); try again
        OUT.mkdir(parents=True, exist_ok=True)
        texture.save_to_png(str(OUT / f"{name}.png"))
        print(f"saved {name}.png {width}x{height}", flush=True)
        self.next_scene()
        return GLib.SOURCE_REMOVE


if __name__ == "__main__":
    ShotApp().run([sys.argv[0]])
