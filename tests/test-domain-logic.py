#!/usr/bin/python3
"""Unit tests for the GUI's pure logic. Run: python3 tests/test-domain-logic.py"""
import pathlib
import runpy
import unittest
from types import SimpleNamespace

APP = SimpleNamespace(**runpy.run_path(
    str(pathlib.Path(__file__).resolve().parents[1] / "src" / "zapret-sites-gui"), run_name="zapret_sites_gui"
))


class ParseDomainsTest(unittest.TestCase):
    def test_trims_lowercases_and_skips_blank_lines(self):
        valid, invalid = APP.parse_domains("  Discord.com \r\n\n\tx.com\n")
        self.assertEqual(valid, ["discord.com", "x.com"])
        self.assertEqual(invalid, [])

    def test_drops_duplicates_keeping_first_position(self):
        valid, _ = APP.parse_domains("b.com\na.com\nB.com\n")
        self.assertEqual(valid, ["b.com", "a.com"])

    def test_reports_invalid_lines(self):
        valid, invalid = APP.parse_domains("ok.com\nbad domain\nhttps://x.com\n*.cdn.net\n")
        self.assertEqual(valid, ["ok.com", "*.cdn.net"])
        self.assertEqual(invalid, ["bad domain", "https://x.com"])

    def test_rejects_a_trailing_newline_inside_a_single_value(self):
        self.assertIsNone(APP.DOMAIN_RE.fullmatch("a.com\n"))


class PresetTest(unittest.TestCase):
    def test_preset_is_enabled_only_when_all_domains_are_present(self):
        self.assertEqual(APP.enabled_presets(["discord.gg", "discord.com", "discordapp.com"]), {"Discord"})
        self.assertEqual(APP.enabled_presets(["discord.gg", "discord.com"]), set())

    def test_custom_domains_exclude_enabled_presets_only(self):
        domains = ["discord.gg", "discord.com", "discordapp.com", "x.com", "example.org"]
        self.assertEqual(APP.custom_domains(domains), ["x.com", "example.org"])


class ParseStatusTest(unittest.TestCase):
    def test_reads_key_value_lines(self):
        self.assertEqual(
            APP.parse_status("zapret=active\ndns=inactive\nnoise\n"),
            {"zapret": "active", "dns": "inactive"},
        )

    def test_empty_output_gives_empty_dict(self):
        self.assertEqual(APP.parse_status(""), {})


if __name__ == "__main__":
    unittest.main()
