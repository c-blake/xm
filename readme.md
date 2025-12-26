# `xzoom`-alike written in Nim, simplified & extended to become `xm`

![chromeInlineImg.gif](media/chromeInlineImg.gif)

## Installation
A simple `nimble install xm` *should* work, but if it does not, you can (in any
scratch directory) do (either as root or amended with appropriate `sudo`/etc.):
```sh
git clone https://github.com/c-blake/cligen
git clone https://github.com/c-blake/xm
cd ./xm
nim c -p=../cligen -d:release xm &&
  install -cm755 xm /usr/local/bin &&
  install -cm444 xm.1 /usr/local/share/man/man1
```
Either way, you probably want to create a `$HOME/.config/xm` (`cfg/xm` in the
repo is an example).  Then all you need to do is run `xm&`.  I've not yet tried
building the binary on anything beyond Linux, but I'd expect most BSDs would
work well.  { X11 compatibility layers, e.g.  XQuartz on OSX, require (at least)
screen recording perms, but basically if `xmag` works then so should `xm`, but
it could be some work to get going }.

## Applications
I have UHD (aka 2160p aka 4K) displays.  I occasionally use old programs like
`fontforge` or `xv` with tiny UI fonts and no easy way to alter/upscale them.
`xm` to the rescue!  Looking at realized font rendering & glyphs is another
idea.  Temporary zoom for a guest with poorer eyesight or who is further away
from the screen is another.  More generally, it's not bad for any presentation
to guide audience attention.  There are web pages where firefox/chrome mess up
page layouts quite a bit or literally will not zoom the page element you want.
This bypasses layout complexity using dynamic redraws over an unrelated window.
(This is the example in the animated GIF of this `readme.md` where a quick
screenshot was unzoomable while the surround text was.)  There are surely more
since "I see" has come to broadly mean "I understand", perhaps culminating in
"icic" chat-ese { or lately maybe some emoji(s)? }.

This tool is dynamic - it reads the input area over and over again and can keep
up with high frame rates updates.  (E.g., if in the example above, were chrome
scrolling quickly, the zoomed view would also scroll quickly).  Even so, it
should be pretty fast &| use little CPU.  For small, static 128x128 pixel areas,
I clocked it at 36000+ FPS on a 2023-era i7-1370P Linux box running vanilla
xorg.  With CLI flags and keys you can turn on / off the bounding box or chasing
the pointer or a re-spaceable/shiftable grid etc.  The man page
[xm.1](https://c-blake.github.io/xm/media/xm.html) more completely documents it.

## Sources / History
While a manual re-write in Nim to a degree that copyright makes little sense, it
would also be unfair to shoulders I stood upon to dub it "from scratch".  Ideas,
but not really code came from:
  https://github.com/mbarakatt/xzoom-follow-mouse
..basically a patch of a Debian-patched xzoom by Itai Nahshon <nahshon@best.com>
with improvements by Markus F.X.J Oberhumer and Tony Mancill.

For those familiar with `xzoom`, here are some headliner deltas.  All UI knobs
are also CLI-accessible & there is a new print-config action to recreate them.
Bbox drawing & pointer tracking are *UI* ideas (NOT compile-time options) and
Shape-extension based bounding boxes not a stray pixel-prone xor GC.  UI motion
step sizes are UI-editable as is grid spacing *and* alignment.  XSHM is tested
for & ordinary X is used if not available (or forced) { not so bad on GigaBit
LANs }.  The CLI is [`cligen`](https://github.com/c-blake/cligen) which gives
`~/.config/xm` for almost free.  `-i` overrides `-o` (more robust than erroring
out).  Weakly helpful rotation & dynamic window titles complexity is all gone.
(I don't even do title bars on my WM, and it seems ok to leave `xm&` printing
`stdout`).  Also added a watch feature to trigger `p` externally & toggle chase
(since you may want to position w/the pointer & then freeze w/sloppy focus WM).
I also added WM resize increments to track (mX, mY), better X11 error handling
function to detail / filter err codes, preventing mouse clipping/panning areas
from going off-screen, minimum window sizes (hard-coded to 6x6 for now) for key
repeat oopses, on-screen help & its toggle for UI, input-data-hash-based skips
of unchanged frames and wrote a new man page to reflect all the new realities.
There are likely many things I've forgotten.  At this point, it's only a vaguely
similar program in philosophy in another PLang, but one users might enjoy more.
Going forward, consult the version control log.

## License
Original license is in http://webdiis.unizar.es/pub/unix/X11/xzoom-0.3.tgz . The
main file in the mbarakatt github has the other.  My license - standard MIT-ISC
credit-where-it's-due style (as I do here even though it's all new code).
