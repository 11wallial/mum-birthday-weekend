"""The one-screen-tells-the-story test, at the size the story is told.

A viewer meets this game as a 320-pixel-wide thumbnail on a directory page,
or as a stream compressed to within an inch of its life. The bar is that the
board, what is owed, what is held and the count all read at that size; the
handover called it the streamability check and nobody had run it properly.

    python3 tools/visual_qa/thumbnail.py                 # every shot on disk
    python3 tools/visual_qa/thumbnail.py 04_spin_1 ...   # named shots

Writes <name>.thumb.png (320x180, the directory's own size) and
<name>.read.png (that thumbnail at 3x nearest, which is how to look at it
without pretending the pixels are back). Also prints the ink: how much of
the frame is above half brightness, because a thumbnail that is 2% lit is a
black rectangle in a grid of bright ones however well it reads up close.
"""
import pathlib
import subprocess
import sys

SHOTS = pathlib.Path.home() / ("Library/Application Support/Godot/app_userdata"
                               "/Break the Bank/shots")
THUMB = (320, 180)
LOOK = 3


def run(args: list[str]) -> str:
	done = subprocess.run(args, capture_output=True, text=True)
	if done.returncode != 0:
		raise SystemExit(done.stderr.strip().splitlines()[-1] if done.stderr else "ffmpeg failed")
	return done.stdout


def ink(path: pathlib.Path) -> float:
	"""The share of the thumbnail above half brightness — read out of the
	pixels rather than out of ffmpeg's log, which says nothing at -v error."""
	import numpy
	done = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-f", "rawvideo",
			"-pix_fmt", "gray", "-"], capture_output=True)
	if done.returncode != 0 or not done.stdout:
		return 0.0
	pixels = numpy.frombuffer(done.stdout, dtype=numpy.uint8)
	return float((pixels >= 128).mean())


def main(names: list[str]) -> int:
	if not SHOTS.exists():
		print("no shots at %s — run tools/visual_qa/screenshot.gd first" % SHOTS)
		return 2
	shots = [SHOTS / ("%s.png" % name) for name in names] if names else sorted(
			p for p in SHOTS.glob("*.png") if ".thumb" not in p.name and ".read" not in p.name)
	if not shots:
		print("nothing to read")
		return 2
	print("%-22s %8s  %s" % ("shot", "lit", "thumbnail"))
	for shot in shots:
		if not shot.exists():
			print("%-22s  missing" % shot.stem)
			continue
		thumb = shot.with_suffix(".thumb.png")
		look = shot.with_suffix(".read.png")
		run(["ffmpeg", "-y", "-v", "error", "-i", str(shot), "-vf",
				"scale=%d:%d:flags=area" % THUMB, str(thumb)])
		run(["ffmpeg", "-y", "-v", "error", "-i", str(thumb), "-vf",
				"scale=%d:%d:flags=neighbor" % (THUMB[0] * LOOK, THUMB[1] * LOOK), str(look)])
		print("%-22s %7.1f%%  %s" % (shot.stem, ink(thumb) * 100.0, thumb.name))
	print("\nRead the .read.png files. The bar: the board, what is owed, what is "
			"held and the count.")
	return 0


if __name__ == "__main__":
	raise SystemExit(main(sys.argv[1:]))
