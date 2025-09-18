from v8_deps import deps
from download_file import DownloadUrl
from pathlib import Path
import platform
import os
import tempfile
import tarfile
import sys

DIR = 'third_party/rust-toolchain'

host_os = platform.system().lower()
if host_os == "darwin":
    host_os = "mac"
elif host_os == "windows":
    host_os = "win"

host_cpu = platform.machine().lower()
if host_cpu == "x86_64":
    host_cpu = "x64"
elif host_cpu == "aarch64":
    host_cpu = "arm64"


if os.path.exists(DIR):
    print(f'{DIR}: already downloaded')
    sys.exit()

eval_globals = {
    'host_os': host_os,
    'host_cpu': host_cpu,
}

dep = deps[DIR]
obj = next(obj for obj in dep['objects'] if eval(obj['condition'], eval_globals))
bucket = dep['bucket']
name = obj['object_name']
url = f'https://storage.googleapis.com/{bucket}/{name}'


def EnsureDirExists(path):
    if not os.path.exists(path):
        os.makedirs(path)


def DownloadAndUnpack(url, output_dir):
    """Download an archive from url and extract into output_dir."""
    with tempfile.TemporaryFile() as f:
        DownloadUrl(url, f)
        f.seek(0)
        EnsureDirExists(output_dir)
        with tarfile.open(mode='r:xz', fileobj=f) as z:
            z.extractall(path=output_dir)


DownloadAndUnpack(url, DIR)

# The Win rust-toolchain archive is currently only available for x64
if host_cpu == 'arm64' and host_os == 'win':
    # Install the nightly toolchain for arm64
    os.system('rustup target add aarch64-pc-windows-msvc --toolchain nightly')
    # install native bindgen-cli
    root = Path.home() / ".rustup" / "toolchains" / "nightly-aarch64-pc-windows-msvc"
    if not (root / "bin" / "bindgen.exe").exists():
        os.system(f'cargo install bindgen-cli --force --root {root}')
    os.system(f'robocopy {root} {DIR} *.exe *.dll /S')
    # one liner to write version file
    with open(os.path.join(DIR, 'VERSION'), 'w') as f:
        version = os.popen(f'{root / "bin" / "rustc.exe"} -V').read().strip()
        f.write(version)
