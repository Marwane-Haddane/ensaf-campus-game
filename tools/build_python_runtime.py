"""Build the private Python runtime shipped next to the game exe (release zips).

The Operation Blackout lab runs a bounded Python interpreter
(scripts/cyber/python_lab_source.gd). Release builds carry their own Python so
players need nothing installed. Uses the local CPython (PSF licence permits
redistribution); only the stdlib parts the worker can reach are zipped.

Usage: python tools/build_python_runtime.py OUT_DIR
"""
import shutil
import sys
import zipfile
from pathlib import Path

SKIP_DIRS = {"site-packages", "test", "tests", "idlelib", "tkinter", "turtledemo", "ensurepip", "lib2to3",
             "pydoc_data", "venv", "unittest", "sqlite3", "curses", "dbm", "xmlrpc", "wsgiref", "__pycache__",
             "asyncio", "concurrent", "multiprocessing", "email", "http", "html", "urllib", "xml", "tomllib",
             "zoneinfo", "_pyrepl", "lib-tk", "msilib", "distutils", "pathlib"}


def main():
    out = Path(sys.argv[1])
    home = Path(sys.base_prefix)
    tag = "python%d%d" % sys.version_info[:2]
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    for name in ("python.exe", tag + ".dll", "python3.dll", "vcruntime140.dll", "vcruntime140_1.dll", "LICENSE.txt"):
        if (home / name).exists():
            shutil.copy2(home / name, out / name)
    lib = home / "Lib"
    with zipfile.ZipFile(out / (tag + ".zip"), "w", zipfile.ZIP_DEFLATED) as archive:
        for path in lib.rglob("*.py"):
            rel = path.relative_to(lib)
            if any(part in SKIP_DIRS for part in rel.parts):
                continue
            archive.write(path, rel.as_posix())
    # ._pth puts Python in isolated embedded mode: only the zip, no registry/PATH lookups.
    (out / (tag + "._pth")).write_text(tag + ".zip\n.\n", encoding="ascii")
    print("python runtime", sys.version.split()[0], "->", out)


if __name__ == "__main__":
    main()
