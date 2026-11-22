"""Assemble a no-install Windows release folder around an exported game exe.

Usage (after `Godot --headless --export-release "Windows Desktop" <DIR>/<Name>.exe`):
    python tools/package_release.py <DIR> <Name> "<readme title>"

Adds next to the exe:
  cef_artifacts/  embedded Chromium (gdcef) + gdcef_release.gdextension, which
                  scripts/web_runtime.gd loads by absolute path, plus the VC++
                  runtime DLLs libgdcef.dll needs (app-local, no redist install)
  python/         private Python for the Operation Blackout lab
                  (tools/build_python_runtime.py)
  README.txt
and removes the stray libgdcef.dll Godot copies beside the exe.
"""
import shutil
import subprocess
import sys
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
VC_RUNTIME = ("msvcp140.dll", "vcruntime140.dll", "vcruntime140_1.dll")
RELEASE_EXTENSION = """[configuration]
entry_symbol = "gdcef_library_init"
compatibility_minimum = 4.2

[libraries]
windows.x86_64.debug = "libgdcef.dll"
windows.x86_64.release = "libgdcef.dll"
"""
README = """{title}

HOW TO PLAY
1. Right-click the zip and choose "Extract All". Do not run it from inside the zip.
2. Open the extracted folder and double-click {name}.exe.
   If Windows shows "Windows protected your PC", click "More info", then "Run anyway".

Nothing to install: the web browser (cef_artifacts) and the Python used by the
Operation Blackout lab (python) are included. Keep these folders next to the exe.

64-bit Windows 10 or 11. Logs: %APPDATA%\\Godot\\app_userdata\\{app}\\logs\\
"""


def main():
    out, name, title = Path(sys.argv[1]), sys.argv[2], sys.argv[3]
    app = sys.argv[4] if len(sys.argv) > 4 else name.replace("-", " ")
    exe = out / (name + ".exe")
    if not exe.exists():
        sys.exit("export the game first: " + str(exe))
    (out / "libgdcef.dll").unlink(missing_ok=True)
    cef = out / "cef_artifacts"
    if cef.exists():
        shutil.rmtree(cef)
    shutil.copytree(PROJECT / "cef_artifacts", cef, ignore=shutil.ignore_patterns("*.lib", "*.exp", "*.gdextension", "*.uid"))
    (cef / "gdcef_release.gdextension").write_text(RELEASE_EXTENSION, encoding="ascii")
    system32 = Path(r"C:\Windows\System32")
    for dll in VC_RUNTIME:
        shutil.copy2(system32 / dll, cef / dll)
    python = out / "python"
    subprocess.run([sys.executable, str(Path(__file__).with_name("build_python_runtime.py")), str(python)], check=True)
    (out / "README.txt").write_text(README.format(title=title, name=name, app=app), encoding="utf-8")
    print("release folder ready:", out)


if __name__ == "__main__":
    main()
