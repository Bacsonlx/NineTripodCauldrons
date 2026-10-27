import subprocess
import sys
import unittest
import shlex
import tempfile
import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class PlayCommandChecks(unittest.TestCase):
    def test_default_uses_current_project_entry(self):
        result = subprocess.run(
            [sys.executable, str(ROOT / "play"), "--dry-run"],
            cwd=tempfile.gettempdir(), capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(str(ROOT / "godot"), result.stdout)
        self.assertNotIn("potion-drops", result.stdout)

    def invoke(self, *arguments):
        return subprocess.run([sys.executable, str(ROOT / "play"), "--dry-run", *arguments], capture_output=True, text=True)

    def test_boss_resources_are_forwarded_as_game_arguments(self):
        result = self.invoke("--test", "boss", "--health", "40", "--mana", "0", "--stamina", "0")
        self.assertEqual(result.returncode, 0, result.stderr)
        command = shlex.split(result.stdout)
        self.assertEqual(command[command.index("--") + 1:], ["--test=boss", "--health=40", "--mana=0", "--stamina=0"])

    def test_quality_is_forwarded_as_game_argument(self):
        result = self.invoke("--quality", "auto")
        command = shlex.split(result.stdout)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--quality=auto", command)
        self.assertLess(command.index("--"), command.index("--quality=auto"))

    def test_rules_always_run_headless(self):
        result = self.invoke("--test", "rules")
        self.assertEqual(result.returncode, 0, result.stderr)
        command = shlex.split(result.stdout)
        self.assertIn("--headless", command)
        self.assertIn("res://tests/run_tests.gd", command)
        self.assertNotIn("--", command)

    def test_drops_room_and_seed_are_forwarded(self):
        result = self.invoke("--test", "drops", "--room", "court2", "--seed", "13", "--headless", "--quit-after", "3")
        self.assertEqual(result.returncode, 0, result.stderr)
        command = shlex.split(result.stdout)
        self.assertIn("--room=court2", command)
        self.assertIn("--seed=13", command)
        self.assertLess(command.index("--headless"), command.index("--"))

    def test_invalid_or_unsupported_conditions_fail_before_start(self):
        for arguments in [
            ["--health", "0"], ["--mana", "101"], ["--stamina", "-1"], ["--seed", "-1"],
            ["--room", "missing"], ["--test", "missing"], ["--test", "boss", "--room", "court2"],
            ["--test", "alpha", "--mana", "0"], ["--test", "rules", "--seed", "13"], ["--quit-after", "0"],
        ]:
            with self.subTest(arguments=arguments):
                result = self.invoke(*arguments)
                self.assertEqual(result.returncode, 2)
                self.assertTrue(result.stderr)

    def test_alpha_is_a_separate_content_selection(self):
        result = self.invoke("--test", "alpha")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--test=alpha", shlex.split(result.stdout))

    @unittest.skipIf(sys.platform == "win32", "进程协议夹具使用 POSIX 可执行脚本")
    def test_rule_script_errors_fail_even_if_engine_exits_zero(self):
        expected = json.loads((ROOT / "godot/engine-lock.json").read_text())["version"]
        with tempfile.TemporaryDirectory() as folder:
            engine = Path(folder) / "godot"
            engine.write_text(
                f"#!{sys.executable}\nimport sys\n"
                f"print({expected!r} if '--version' in sys.argv else 'SCRIPT ERROR: broken rule runner')\n"
            )
            engine.chmod(0o755)
            environment = dict(os.environ, PATH=folder + os.pathsep + os.environ.get("PATH", ""))
            result = subprocess.run(
                [sys.executable, str(ROOT / "play"), "--test", "rules"],
                capture_output=True, text=True, env=environment,
            )
            self.assertEqual(result.returncode, 1)
            self.assertIn("SCRIPT ERROR:", result.stdout)


if __name__ == "__main__":
    unittest.main()
