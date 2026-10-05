#!/bin/sh
# Strata for Linux: the first run installs everything and starts the model; later runs just start it.
# Needs only an NVIDIA driver (or, for an AMD Radeon card, the kernel's amdgpu driver: see docs/AMD_HIP.md).
# Python (with venv) is installed through apt/dnf if it is missing (asks for sudo).
cd "$(dirname "$0")" || exit 1
# Python 3.10+ that can make a venv WITH pip: Debian/Ubuntu ship `venv` without `ensurepip` (that is the separate
# python3-venv package), and a venv made without it has no pip
ok_py() { "$1" -c 'import sys, venv, ensurepip; sys.exit(0 if sys.version_info >= (3, 10) else 1)' 2>/dev/null; }
# a personal venv: the path is recorded in .venv-path; with one in use there is no Python install and no sudo
good_venv() { [ -x "$1/bin/python" ] && "$1/bin/python" -m pip --version >/dev/null 2>&1; }
VENV_PY=""
if [ -f .venv-path ]; then
  saved=$(head -n 1 .venv-path)
  if [ -n "$saved" ] && good_venv "$saved"; then
    VENV_PY="$saved/bin/python"
  else
    echo "The recorded virtual environment ($saved) is not usable any more."
  fi
fi
if [ -z "$VENV_PY" ] && [ -t 0 ]; then
  printf "Use an existing virtual environment of your own? [y/N] "
  read ans
  case "$ans" in
    y|Y|yes|YES|Yes)
      printf "Path to the virtual environment: "
      read vp
      vp=$(eval "printf '%s' $vp" 2>/dev/null) || vp=""
      if [ -n "$vp" ] && [ -d "$vp" ] && good_venv "$vp"; then
        vp=$(cd "$vp" && pwd)
        echo "$vp" > .venv-path
        VENV_PY="$vp/bin/python"
      else
        echo "No usable bin/python and bin/pip there: using the project's .venv instead."
      fi
      ;;
  esac
fi
if [ -n "$VENV_PY" ]; then
  exec "$VENV_PY" setup.py "$@"
fi
# a .venv from an earlier run that failed half-way has a python but no pip: start it again
if [ -x .venv/bin/python ] && ! .venv/bin/python -m pip --version >/dev/null 2>&1; then
  rm -rf .venv
fi
if [ ! -x .venv/bin/python ]; then
  PY=""
  for c in python3 python; do
    if command -v $c >/dev/null 2>&1 && ok_py $c; then
      PY=$c; break
    fi
  done
  if [ -z "$PY" ]; then
    echo "Python 3.10+ with venv is needed; installing it (sudo will ask for your password) ..."
    if command -v apt-get >/dev/null 2>&1; then
      sudo apt-get update && sudo apt-get install -y python3 python3-venv python3-pip
    elif command -v dnf >/dev/null 2>&1; then
      sudo dnf install -y python3 python3-pip
    elif command -v pacman >/dev/null 2>&1; then
      sudo pacman -S --noconfirm python python-pip
    fi
    PY=python3
    if ! ok_py $PY; then
      echo "Please install Python 3.10 or newer with venv (Ubuntu/Debian: sudo apt install python3-venv), then run"
      echo "./setup.sh again."
      exit 1
    fi
  fi
  # a private environment inside this folder (system Python stays untouched; newer distros refuse global pip)
  $PY -m venv .venv || { rm -rf .venv; echo "could not create .venv: sudo apt install python3-venv"; exit 1; }
fi
exec .venv/bin/python setup.py "$@"
