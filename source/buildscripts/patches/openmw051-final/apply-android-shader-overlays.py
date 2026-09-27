#!/usr/bin/env python3
"""Install the final release shader overlays into the OpenMW source tree.

The local-map fog bypass, WetWorld water projective UVs, and the
bs/groundcover fragment tweaks were produced by the (Windows-only)
tools/apply-openmw-051-*.ps1 pipeline and never made it into the committed
python patch series. This script copies the canonical payload files into
the OpenMW source tree before the build, so a clean Linux/Nix build
produces the same runtime resources as the reference 0.51.0-11 release.
Idempotent: re-running simply re-copies the overlay files.
"""

import os
import shutil
import sys

OVERLAY_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                           "shader-overlays", "compatibility")

OVERLAY_FILES = [
    "bs/default.frag",
    "bs/nolighting.frag",
    "groundcover.frag",
    "objects.frag",
    "water.frag",
    "water.vert",
]


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: apply-android-shader-overlays.py <openmw-source-dir>",
              file=sys.stderr)
        return 1
    source_dir = sys.argv[1]
    for rel in OVERLAY_FILES:
        src = os.path.join(OVERLAY_DIR, rel)
        dst = os.path.join(source_dir, "resources", "shaders",
                           "compatibility", rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copyfile(src, dst)
        print(f"overlay: {dst}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
