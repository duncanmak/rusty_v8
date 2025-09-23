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

print(f"host_os: {host_os}, host_cpu: {host_cpu}")

# The Win rust-toolchain archive is currently only available for x64
if True: # host_cpu == 'arm64' and host_os == 'win':
    root = Path.home() / ".rustup" / "toolchains" / "nightly-aarch64-pc-windows-msvc"

    # install native bindgen-cli
    if not (root / "bin" / "bindgen.exe").exists():
        print("Installing native bindgen-cli")
        os.system(f'cargo install bindgen-cli --force --root {root}')

    # write version file
    print("Writing VERSION file")
    with open(os.path.join(root, 'VERSION'), 'w') as f:
        version = os.popen(f'{root / "bin" / "rustc.exe"} -V').read().strip()
        f.write(version)

    # Replace x64 clang.dll with ARM native
    with tempfile.TemporaryFile() as f:
        url = "https://github.com/llvm/llvm-project/releases/download/llvmorg-21.1.1/clang+llvm-21.1.1-aarch64-pc-windows-msvc.tar.xz"
        DownloadUrl(url, f)
        f.seek(0)
        with tarfile.open(mode='r:xz', fileobj=f) as z:
            member_path = "clang+llvm-21.1.1-aarch64-pc-windows-msvc/bin/libclang.dll"
            dest_path = os.path.join(root, "bin", "libclang.dll")
            member = z.getmember(member_path)
            with z.extractfile(member) as source, open(dest_path, 'wb') as destination:
                destination.write(source.read())

    # Copy everything over
    os.system(f'robocopy {root} {DIR} VERSION *.exe *.dll /S')
