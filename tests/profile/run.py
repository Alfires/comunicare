import os, pathlib, shutil, subprocess, tempfile
ROOT=pathlib.Path(__file__).resolve().parents[2]
HERE=pathlib.Path(__file__).resolve().parent
def main():
 with tempfile.TemporaryDirectory(dir="/tmp/opencode",prefix="commit-core-") as d:
  p=pathlib.Path(d)
  for name in SOURCES:
   (p/name).parent.mkdir(parents=True,exist_ok=True)
   shutil.copy2(ROOT/name,p/name)
  shutil.copy2(HERE/"suite.gd",p/"suite.gd")
  (p/"project.godot").write_text('config_version=5\n[application]\nconfig/name="Core contracts"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
  for args in [["--editor","--import"],["--script","res://suite.gd"]]:
   r=subprocess.run([os.environ.get("GODOT","godot"),"--headless","--path",d,*args],capture_output=True,text=True)
   output=r.stdout+r.stderr
   if "--script" in args or r.returncode or "ERROR:" in output: print(output,end="")
   if "ERROR:" in output: return 2
   if r.returncode: return r.returncode
 return 0
SOURCES=['scripts/profile/profile_identity.gd', 'scripts/profile/profile_service.gd', 'scripts/profile/identity_authenticator.gd']
if __name__=="__main__": raise SystemExit(main())
