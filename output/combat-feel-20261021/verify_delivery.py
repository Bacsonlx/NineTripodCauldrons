from pathlib import Path
import subprocess,tempfile,shutil,zipfile,json,hashlib
P=Path(__file__).resolve().parent;ROOT=P.parents[1];results=[]
def run(command):
 r=subprocess.run(command,capture_output=True,text=True,timeout=60)
 output=r.stdout+r.stderr
 ok=r.returncode==0 and 'ERROR:' not in output
 print(command[0],command[-1], 'PASS' if ok else output,flush=True)
 results.append({'command':command,'exit_code':r.returncode,'pass':ok,'output':output})
 if not ok:raise SystemExit(1)
with tempfile.TemporaryDirectory(prefix='jiuding-waves-clean-') as tmp:
 project=Path(tmp)/'godot';shutil.copytree(ROOT/'godot',project,ignore=shutil.ignore_patterns('.godot'))
 run(['godot','--headless','--path',str(project),'--editor','--import'])
 for script in ['wave_checks.gd','combat_feedback_checks.gd','room_layout_checks.gd']:
  run(['godot','--headless','--path',str(project),'--script','res://tests/'+script])
 archive=ROOT/'build/godot/NineTripods-godot-macos.zip'
 with zipfile.ZipFile(archive) as z:
  assert z.testzip() is None
  z.extractall(Path(tmp)/'native')
  pack=z.read(next(n for n in z.namelist() if n.endswith('.pck')))
  for asset in ['scenes/rooms/court1','scenes/rooms/court2','scenes/rooms/court3','scripts/presentation/combat_effects','scripts/journey/journey_room']:
   assert asset.encode() in pack,asset
  binaries=[n for n in z.namelist() if '/Contents/MacOS/' in n and not n.endswith('/')];assert len(binaries)==1
 binary=Path(tmp)/'native'/binaries[0];binary.chmod(0o755)
 run([str(binary),'--headless','--quit-after','3'])
packages={}
for name in ['NineTripods-godot-macos.zip','NineTripods-godot-windows.zip']:
 file=ROOT/'build/godot'/name
 with zipfile.ZipFile(file) as z:assert z.testzip() is None
 packages[name]={'sha256':hashlib.sha256(file.read_bytes()).hexdigest(),'bytes':file.stat().st_size}
(P/'delivery-verification.json').write_text(json.dumps({'fresh_import_and_native_checks':results,'packages':packages,'mac_pck_contains_room_and_effect_scripts':True,'foreground_tested':False,'windows_started':False,'limitation':'Exported release did not complete an external-script custom audit; only normal headless startup and PCK path inspection are claimed.'},ensure_ascii=False,indent=2)+'\n')
print('DELIVERY PASS',flush=True)
