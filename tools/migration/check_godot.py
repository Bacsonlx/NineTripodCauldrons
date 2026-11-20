"""Verify the locked engine, import, public tests and full scene; fail on script errors."""
import os
import json
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
subprocess.run([sys.executable, str(root / "tools/tests/test_play.py")], check=True)
lock = json.loads((root / "godot/engine-lock.json").read_text())
version = subprocess.check_output(["godot", "--version"], text=True).strip()
if version != lock["version"]:
    raise SystemExit(f"Godot version mismatch: {version}; expected {lock['version']}")
commands = [["--editor", "--import"], ["--script", "res://tests/run_tests.gd"], ["--script", "res://tests/terrain_collision_checks.gd"], ["--script", "res://tests/performance_checks.gd"], ["--script", "res://tests/first_level_checks.gd"], ["--script", "res://tests/first_level_visual_checks.gd"], ["--script", "res://tests/map_revision_checks.gd"], ["--script", "res://tests/room_journey_checks.gd"], ["--script", "res://tests/room_layout_checks.gd"], ["--script", "res://tests/portal_presentation_checks.gd"], ["--script", "res://tests/wave_checks.gd"], ["--script", "res://tests/combat_feedback_checks.gd"], ["--script", "res://tests/room_flow_checks.gd"], ["--script", "res://tests/hud_checks.gd"], ["--script", "res://tests/energy_checks.gd"], ["--quit-after", "3"], ["res://scenes/tanggu_first_level.tscn", "--quit-after", "3"]]
commands.insert(-2, ["--script", "res://tests/boss_scene_checks.gd"])
commands.insert(-2, ["--script", "res://tests/action_frame_checks.gd"])
commands.insert(-2, ["--script", "res://tests/home_flow_checks.gd"])
commands.insert(-2, ["--script", "res://tests/safehouse_flow_checks.gd"])
commands.insert(-2, ["--script", "res://tests/home_ui_checks.gd"])
commands.insert(-2, ["--script", "res://tests/boss_integration_checks.gd"])
commands.append(["res://scenes/boss_test.tscn", "--quit-after", "3"])
commands.append(["--script", "res://tests/loot_scene_checks.gd"])
for options in [[], ["--test=boss", "--health=40", "--mana=0", "--stamina=0", "--seed=13"], ["--test=drops", "--health=60", "--mana=40", "--seed=13"], ["--room=court2"], ["--quality=low"], ["--test=alpha"]]:
    commands.append(["--script", "res://tests/launch_scene_checks.gd", "--", *options])
commands.append(["--script", "res://tests/boss_art_checks.gd"])
commands.append(["res://scenes/boss_art_test.tscn", "--quit-after", "3"])
commands.append(["--script", "res://tests/boss_motion_candidate_checks.gd"])
commands.append(["res://scenes/boss_motion_candidate_test.tscn", "--quit-after", "3"])
commands.append(["--script", "res://tests/thor_rig_pilot_checks.gd"])
commands.append(["res://scenes/prototypes/thor_rig_pilot_test.tscn", "--quit-after", "3"])
commands.insert(-2, ["--script", "res://tests/gameplay_journey_checks.gd"])
commands.insert(-2, ["--script", "res://tests/gameplay_scene_checks.gd"])
commands.insert(-2, ["--script", "res://tests/equipment_source_checks.gd"])
commands.insert(-2, ["--script", "res://tests/skill_journey_checks.gd"])
commands.insert(-2, ["--script", "res://tests/skill_scene_checks.gd"])
commands.insert(-2, ["--script", "res://tests/item_prototype_checks.gd"])
commands.insert(-2, ["--script", "res://tests/item_scene_checks.gd"])
commands.insert(-2, ["--script", "res://tests/backpack_deep_checks.gd"])
commands.insert(-2, ["--script", "res://tests/backpack_drag_checks.gd"])
commands.insert(-2, ["--script", "res://tests/home_backpack_drag_checks.gd"])
commands.insert(-2, ["--script", "res://tests/formal_ui_checks.gd"])
commands.insert(-2, ["--script", "res://tests/commercial_depth_checks.gd"])
for name in ["expanded_map_checks", "expanded_journey_checks", "expanded_home_checks", "expanded_reading_checks", "route_sample_checks"]:
    commands.append(["--script", f"res://tests/{name}.gd"])
sandbox_home = Path("/private/tmp/godot-home")
sandbox_home.mkdir(parents=True, exist_ok=True)
godot_env = os.environ.copy()
if not os.access(Path.home(), os.W_OK):
    godot_env["HOME"] = str(sandbox_home)

for args in commands:
    command = ["godot", "--headless", "--path", str(root / "godot"), *args]
    print("Running (timeout 180s): " + " ".join(command), flush=True)
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=180, env=godot_env)
    except subprocess.TimeoutExpired as error:
        for captured in [error.stdout, error.stderr]:
            if captured:
                sys.stderr.write(captured.decode(errors="replace") if isinstance(captured, bytes) else captured)
        sys.stderr.write("Godot check timed out after 180s: " + " ".join(args) + "\n")
        raise SystemExit(124)
    output = result.stdout + result.stderr
    filtered = output.replace('ERROR: Condition "ret != noErr" is true. Returning: ""', '').replace('at: get_system_ca_certificates (platform/macos/os_macos.mm:1035)', '')
    filtered_lines = [
        line for line in filtered.splitlines()
        if "RID allocations of type" not in line
        and "RIDs of type" not in line
        and "ObjectDB instances were leaked at exit" not in line
        and "at: _free_rids" not in line
        and "at: cleanup (servers/rendering/renderer_dummy" not in line
    ]
    filtered = "\n".join(filtered_lines)
    if result.returncode or "SCRIPT ERROR:" in filtered or "ERROR:" in filtered:
        sys.stderr.write(output)
        raise SystemExit(result.returncode or 1)
    if "--script" in args:
        print(output.strip(), flush=True)
print("Godot engine/import/public tests/full scene: passed")
