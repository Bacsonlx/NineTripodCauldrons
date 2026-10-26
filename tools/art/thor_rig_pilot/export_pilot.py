"""Export pilot-only entry points from a temporary copy; keep the live entry intact."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'build/godot'

def run(project, args):
    result = subprocess.run(['godot','--headless','--path',str(project),*args],capture_output=True,text=True,timeout=180)
    output = result.stdout + result.stderr
    if result.returncode or 'ERROR:' in output or 'SCRIPT ERROR:' in output:
        raise SystemExit(output)
    print('Passed:',args,flush=True)

with tempfile.TemporaryDirectory(prefix='thor-rig-package-') as directory:
    project = Path(directory) / 'godot'
    shutil.copytree(ROOT/'godot',project,ignore=shutil.ignore_patterns('.godot'))
    config = project/'project.godot'
    old = 'run/main_scene="res://scenes/tanggu_first_level.tscn"'
    source = config.read_text()
    if old not in source:
        raise SystemExit('Unexpected main scene; refusing to guess pilot entry replacement')
    config.write_text(source.replace(old,'run/main_scene="res://scenes/prototypes/thor_rig_pilot_test.tscn"',1))
    run(project,['--editor','--import'])
    run(project,['--script','res://tests/thor_rig_pilot_checks.gd'])
    targets = [('macOS Universal',OUT/'thor-rig-pilot-macos.zip'),('Windows x64',OUT/'thor-rig-pilot-windows/NineTripods-ThorRigPilot.exe')]
    for preset, output in targets:
        output.parent.mkdir(parents=True,exist_ok=True)
        run(project,['--export-release',preset,str(output)])
    with zipfile.ZipFile(targets[0][1]) as archive:
        archive.extractall(Path(directory)/'macos')
    executable = next(p for p in (Path(directory)/'macos').glob('*.app/Contents/MacOS/*') if p.is_file())
    executable.chmod(0o755)
    result = subprocess.run([str(executable),'--headless','--quit-after','3'],capture_output=True,text=True,timeout=60)
    output = result.stdout + result.stderr
    if result.returncode or 'ERROR:' in output or 'SCRIPT ERROR:' in output:
        raise SystemExit(output)
    print('Packaged macOS pilot headless start passed; Windows exported, not run',flush=True)
