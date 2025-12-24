import std/[syncio,strformat,hashes],xmpkg/x,cligen/sysUt # 0) IMPORTS & GLOBALS
template E(a: varargs[untyped]) = stderr.write a, "\n"  # Like echo but ->stderr

var d: ptr Display; var s: ptr Screen; var w,wB: Window # X11 & CLI Globals
var gc, xc: GC; var hf: ptr XFontStruct                 # Copy&Xor GCs, HelpFont
var iX, iY, oX, oY, shmOp, ev0, er0: cint               # Upper Left of I,O;XShm
var (mX, mY) = (3u16,3u16); var (sU, sS) = (8u16,1u16)  # Mags & Steps
var Box, Chase, shm: bool                               # Flags: box, chase, shm
var BW = 5.cuint; var BC = 0xFF0000.culong              # BBox Width & Color
var gS = [30u16,30]; var gO = [0u16,0]  # Horizontal,Vertical Grid Space/Offset
type ImIx = enum I, O                                   # Image I)n O)ut Index
var W, H: array[ImIx, cuint]

template pc =                           # ) p)rint c)onfig from Globals&Defaults
  var m = "xm"
  (if mX != 3: m.add &" -x{mX}"); (if mY != 3: m.add &" -y{mY}")
  (if sU != 8: m.add &" -u{sU}"); (if sS != 1: m.add &" -s{sS}")
  m.add &" -i {W[I]}x{H[I]}+{iX}+{iY}"
  (if gS[0]!=30:m.add &" --gHS={gS[0]}"); (if gO[0]!=30:m.add &" --gHO={gO[0]}")
  (if gS[1]!=30:m.add &" --gVS={gS[1]}"); (if gO[1]!=30:m.add &" --gVO={gO[1]}")
  (if Box: m.add " -b"); (if Chase: m.add " -c"); echo m

var si: array[ImIx, XShmSegmentInfo]    # 1) SHARED MEMORY S)EGMENT I)NFOS
var im: array[ImIx, ptr XImage]         # W,H,si,im are parallel-indexed arrays
proc bytes(imP: ptr XImage): csize_t = csize_t(imP.bytes_per_line*imP.height)
proc imgsMake() =
  for j in [I, O]:
    if shm:
      if (im[j] = d.XShmCreateImage(s.root_visual, s.root_depth, ZPixmap, nil,
                                    si[j].addr, W[j], H[j]); im[j].isNil):
        quit "XShmCreateImage: " & $errno.strerror,5
      si[j].shmid = shmget(IPC_PRIVATE, im[j].bytes, IPC_CREAT or 0o777)
      if si[j].shmid < 0: quit "shmget: " & $errno.strerror,6
      si[j].shmaddr = cast[pointer](shmat(si[j].shmid, nil, 0))
      if si[j].shmaddr == cast[pointer](-1): quit "shmat: " & $errno.strerror,7
      im[j].data = si[j].shmaddr # XSync here might fix races &so silence errs..
      si[j].readOnly = 0         #..but also cost & unsure frames even drop.
      if d.XShmAttach(si[j].addr) == 0: quit "XShmAttach: " & $errno.strerror,8
      shmctl si[j].shmid, IPC_RMID, nil
    else:
      if (im[j] = d.XCreateImage(s.root_visual, s.root_depth, ZPixmap, 0,
            alloc(W[j]*H[j]*d.BitmapUnit div 8), W[j],H[j], 32,0); im[j].isNil):
              quit "XCreateImage: " & $errno.strerror,9
      XInitImage im[j]

proc imgsFree() =       #NOTE X server decRefs on hang-up, kernel on proc exit
  for j in [I, O]:      #     Run `ipcs` when gone to verify.
    if shm: d.XShmDetach si[j].addr; shmdt si[j].shmaddr; XDestroyImage im[j]
    else: dealloc im[j].data
                                        # 2) GEOM ADJUSTMENTS & MAIN TRANSFORM
proc clip(x0: var cint; span: var cuint; a, b, min: cint) =
  let x00 = x0                  # Adjust (x0, span) so x0 >= a && x0 + span < b
  if x0 < a             : x0 = a; span.dec x0 - x00
  if x0 + span.cint >= b: span = cuint(b - x0)
  if span.cint < min    : span = min.cuint

template resize =       # Set[O,I] based on i[XY] & m[XY], to keep [I] on-screen
  let old = (W[I], H[I], W[O], H[O])
  W[I] = (W[O] + mX - 1) div mX; clip iX, W[I], 0, s.width , 6
  H[I] = (H[O] + mY - 1) div mY; clip iY, H[I], 0, s.height, 6
  W[O] = mX*W[I]; H[O] = mY*H[I]
  if (W[I], H[I], W[O], H[O]) != old: imgsFree(); imgsMake() # Replace as needed

proc upScl(dB: cuint; pO, pI: pua byte) =   # TRANSFORM WITH GRID
  var iP: array[4, byte]                # input Pixel buf; Up to 32bit-per-pix
  let wO = W[I]*mX                      # post-xf O,I dims
  for yI in 0 ..< H[I]:
    let oRo = cast[pua byte](pO[dB*(yI*mY)*wO].addr)
    var xO  = 0.cuint
    for xI in 0 ..< W[I]:
      copyMem iP[0].addr, pI[dB*(W[I]*yI + xI)].addr, dB.int  # Get pix
      for i in 0u32 ..< mX:                             # mX Dups of I in O
        copyMem oRo[dB*xO].addr, iP[0].addr, dB.int
        if gO[1] < gS[1] and (xO mod gS[1]) == gO[1]:   # Vertical Grid lines
          for b in 0 ..< dB: oRo[dB*xO + b] = oRo[dB*xO + b] xor 255
        inc xO
    for j in 1u32..<mY: copyMem pO[dB*(yI*mY + j)*wO].addr, oRo, dB*wO #mY-1More
    if gO[0] < gS[0]:                   # Horiz. Grid lines; Maybe flip recent
      for j in yI*mY ..< yI*mY + mY:    # One can likely optimize this loop..
        if (j mod gS[0]) == gO[0]:      #..& condition into "just arithmetic".
          let oRo = cast[pua byte](pO[dB*j*wO].addr)
          for b in 0 ..< dB*wO: oRo[b] = oRo[b] xor 255
                                        # 3) UI UTILITY DEFS
var osh = ["xys NEXT +-g do THIS one", "+/- zoom In/Out;bump \'8\'",
 "g toggle x|y G)rid rule","Arrow Pan 8px in sameDir","  SHIFT=>AltPixel/press",
 "  CTRL=>Resize by 8|1px", "  ALT=>GridSpace|Align", "b toggle B)ounding B)ox",
 "c toggle pointer C)hase", "p P)rint re-launch cmd", "h toggle H)elp overlay",
 "q Q)uit"]                             # On-Screen Help

proc badGeom(str: string; x,y: var cint; w,h: var cuint): bool =
  let m = str.cstring.XParseGeometry(x.addr, y.addr, w.addr, h.addr)
  if m == 0: return true
  if (m and XValue) != 0 and (m and XNegative) != 0: x += s.width
  if (m and YValue) != 0 and (m and YNegative) != 0: y += s.height

template bboxUp =
  if Box:
    let B = uint16(BW); let W = uint16(W[I] + 2*B); let H = uint16(H[I] + 2*B)
    d.XMoveResizeWindow wB, iX - B.cint, iY - B.cint, W, H; d.XRaiseWindow wB
    let Rs = [XRectangle(x:0         , y:0         , width: W, height: B      ),
              XRectangle(x:0         , y:int16(H-B), width: W, height: B      ),
              XRectangle(x:0         , y:B.int16   , width: B, height: H - 2*B),
              XRectangle(x:int16(W-B), y:B.int16   , width: B, height: H - 2*B)]
    XShapeCombineRectangles d, wB, 0, 0, 0, Rs[0].addr, 4, 0, 0

proc xErr(_: ptr Display; e: ptr XErrorEvent): cint{.cdecl.} = # FastOps ~ Racy
  if e.request_code.cint==shmOp and e.minor_code.int in[1,2]:return#X_ShmDAttach
  if e.request_code.cint==shmOp and e.minor_code.int in[3,4]:
    E &"MIT-SHM extension present, but ops fail => network transparent mode"
    shm = false; imgsMake(); return             # imgsFree() not needed
  E &"rq={e.request_code}.{e.minor_code} res={e.resourceid:x} e={e.error_code}"

proc queryPtr(roots: seq[Window]): (cint, cint) =
  var i, x, y: cint; var m: cuint; var w: Window # Unused rets; `nil` fails
  for r in roots:
    if d.XQueryPointer(r,w.addr,w.addr, x.addr,y.addr, i.addr,i.addr,m.addr)!=0:
      return (x, y)
  quit "No pointer found",10

var szHn = XAllocSizeHints(); szHn.flags = PMinSize or PResizeInc
proc sizeHints() =                              # Refresh WM resizing controls
  szHn.width_inc  = mX.cint; szHn.min_width  = cint(6*mX)
  szHn.height_inc = mY.cint; szHn.min_height = cint(6*mY)
  d.XSetWMSizeHints w, szHn, XA_WM_NORMAL_HINTS

proc xSetup: (cint, seq[Window], Atom, Atom) =  # 4) X11 SETUP & ArrowKey (AK)
  result[0] = s.root_depth; if result[0] < 8: quit "xm: need >= 8 bits/pixel",4
  XSetErrorHandler xErr
  var gcv: XGCValues; var gM = 0.culong                 # Init copy GC `gc`
  template gcValSet(tag, bit, val) = gcv.tag = val; gM = gM or `GC bit`
  gcValSet plane_mask    , PlaneMask    , AllPlanes
  gcValSet subwindow_mode, SubwindowMode, IncludeInferiors
  gcValSet function      , Function     , GXcopy
  gc = d.XCreateGC(s.root, gM, gcv.addr); gM = 0        # Init xor GC `xc`
  gcValSet foreground    , Foreground   , AllPlanes
  gcValSet plane_mask    , PlaneMask    , s.white_pixel xor s.black_pixel
  gcValSet subwindow_mode, SubwindowMode, IncludeInferiors
  gcValSet function      , Function     , GXxor
  if not hf.isNil: gcValSet font, Font, hf.fid          # font/osh is optional
  xc = d.XCreateGC(s.root, gM, gcv.addr)
  result[1] = newSeq[Window](d.XScreenCount)            # Get roots for screens
  for j, r in mpairs result[1]: r = d.XRootWindow(j.cint)
  let xa = XSetWindowAttributes(background_pixel: s.black_pixel, # Main Drawable
             event_mask: StructureNotifyMask or KeyPressMask)
  w = d.XCreateWindow(s.root, oX,oY, W[O],H[O], 0,result[0], InputOutput,
        s.root_visual, CWEventMask or CWBackPixel, xa.addr)
  d.XChangeProperty w,XA_WM_NAME,XA_STRING,8,PropModeReplace,"xm".cstring,2.cint
  result[2] = d.XInternAtom("WM_PROTOCOLS", 0)          # Work with Window Mgrs
  result[3] = d.XInternAtom("WM_DELETE_WINDOW", 0)
  d.XSetWMProtocols w, result[3].addr, 1; sizeHints(); d.XMapWindow w
  let wa = XSetWindowAttributes(override_redirect: 1, background_pixel: BC)
  wB = d.XCreateWindow(s.root, iX-BW.cint, iY-BW.cint, W[I] + 2*BW, H[I] + 2*BW,
        0,0,InputOutput,s.root_visual,CWOverrideRedirect or CWBackPixel,wa.addr)
  if Box: d.XMapWindow wB; bboxUp                       # Maybe start w/BBox

proc AK(M:cuint; D:var array[ImIx,cuint]; dD:cint; gD:var cint; min,span:cint) =
  let old = (iX, iY, W[I], H[I])        # Pan, Resize, GridSpace, GridAlign
  let j = int(D.addr == W.addr)         # Move *direction of grid corners*
  let dD = dD*cint(if (M and ShiftMask) == 0: sU else: sS)
  case int((M and ControlMask)!=0) or (int((M and AltMask)!=0) shl 1)
  of 0: (if(dD<0 and gD+dD >= 0)or(dD>0 and gD+dD+D[I].cint <= span): inc gD,dD)
  of 1: D[O].inc dD; resize; d.XResizeWindow w, W[O], H[O]      # Ctrl
  of 2: gO[j] = uint16(cint(gO[j] + gS[j]) + dD) mod gS[j]      # Alt
  of 3: inc gS[j], dD; gS[j] = max(2u16, min(512u16, gS[j]))    # Ctrl-Alt
  else: discard # Case-value construction => impossible, but Nim requires(|enum)
  pc; if (iX, iY, W[I], H[I]) != old: bboxUp

proc xm(display="", net=false, font="",fontH=0, xmag=3,ymag=3, outG="",inG="",
 unshifted=8,shifted=1, gHS=30,gHO=30, gVS=30,gVO=30, box=true, BWidth=5,
 BColor=0xFF, chase=true, time=40_000, watch="") = # 5)CLI & ITS POST-PROCESSING
  ## Dynamically, efficiently, interactively magnify/zoom part of an X11 Screen.
  mX = xmag.uint16; mY = ymag.uint16; sU = unshifted.uint16; sS = shifted.uint16
  gS[0] = gHS.uint16; gS[1] = gVS.uint16; gO[0] = gHO.uint16; gO[1] = gVO.uint16
  Box = box; BW = BWidth.cuint; BC = BColor.culong  # Post process cmd-line by..
  Chase = chase; W[O] = mX*256; H[O] = mY*256       #..using & setting globals.
  d = nil.XOpenDisplay; if d.isNil: quit "Cannot open display",1
  s = d.DefaultScreenOfDisplay
  shm=(not net) and d.XQueryExtension("MIT-SHM",shmOp.addr,ev0.addr,er0.addr)!=0
  hf=d.XLoadQueryFont font;if hf.isNil:E &"Cannot load {font}; No OnScreen Help"
  let fH = if fontH!=0: fontH else: (if hf.isNil:0 else: hf.ascent + hf.descent)
  if outG.len>0 and outG.badGeom(oX,oY, W[O],H[O]):
    quit "bad oGeom: " & outG, 2
  (if W[O] != 0: W[I] = W[O] div mX); (if H[O] != 0: H[I] = H[O] div mY)
  if inG.len>0 and inG.badGeom(iX,iY, W[I],H[I]):
    quit "bad iGeom: " & inG, 3
  W[O] = mX*W[I]; H[O] = mY*H[I]; resize; imgsMake() # Ok!  Ready to Go!
  let (depth, roots, WM_PROTO, WM_DEL) = xSetup() # 6)MAIN LOOP SETUP, CONDITION
  let dB = cuint(if depth==8: 1 elif depth<=16: 2 else: 4)  # depth in Bytes
  let S = if sU > sS: sU.addr else: sS.addr     # s +- edit *max* step val
  var nR,nW: cuint; var doX,doY,doS,doH,dty: bool # Misc loop-carried vars/flags
  var (ptrX0, ptrY0) = (cint(-1), cint(-1))     # Init to impossible
  var st0, st: Stat; var hsh0: Hash             # watch status
  template doClr = (doX = false; doY = false; doS = false; dty= true; pc)
  while time==0 or usleep(time.Useconds)==0:    # MAIN LOOP CONDITION
    if watch.len>0 and stat(watch.cstring, st)==0 and st0.st_mtime.int != 0 and
        st.st_mtime.int > st0.st_mtime.int: pc; Chase = false
    st0 = st; inc nR                            # ALWAYS update; First mtime==0
    if Chase:                                   # Xptr chasing mode
      var (pX, pY) = roots.queryPtr             # Get current Xptr location
      let (W2, H2) = (cint(W[I] div 2), cint(H[I] div 2))
      (pX, pY) = (max(W2, min(s.width-W2, pX)), max(H2, min(s.height-H2, pY)))
      if pX - W2 + W[I].cint > s.width : dec pX # [WH][I]mod 2!=0&SOME compilers
      if pY - H2 + H[I].cint > s.height: dec pY #..can lead to off-screen p[XY].
      if (pX, pY) != (ptrX0, ptrY0):            # *Effective* Xptr moved
        (iX, iY) = (pX - W2, pY - H2); (ptrX0, ptrY0) = (pX, ptrY0); bboxUp
    var e: XEvent; while d.XPending>0:  # 7)EVENTS (IF ANY) FOR FRAME
      d.XNextEvent(e.addr); case e.eType        # Usually, there are none!
      of ClientMessage:(if e.xclient.message_type == WM_PROTO and
                             e.xClientDataAtom0 == WM_DEL: quit 0)    # WM quit
      of ConfigureNotify:W[O]=e.xconfigure.width;H[O]=e.xconfigure.height;resize
      of KeyPress: # KEY DISPATCH; Q: CLI-based key rebind w/user `osh` as well?
        case d.XkbKeycodeToKeysym(e.xkey.keycode, 0, 0)   # A)rrow K)eys first
        of XK_Left ,XK_KP_Left :AK e.xkey.state, W, -1, iX, 6, s.width ;dty=true
        of XK_Right,XK_KP_Right:AK e.xkey.state, W, +1, iX, 6, s.width ;dty=true
        of XK_Up   ,XK_KP_Up   :AK e.xkey.state, H, -1, iY, 6, s.height;dty=true
        of XK_Down ,XK_KP_Down :AK e.xkey.state, H, +1, iY, 6, s.height;dty=true
        of XK_x: doX = true; doY = false; doS = false; E "x-mode"
        of XK_y: doY = true; doX = false; doS = false; E "y-mode"
        of XK_s: doS = true; doX = false; doY = false; E "s-mode"
        of XK_plus, XK_equal, XK_KP_Add:        # '+' in all 3 modes
          if doS: S[] += uint16(S[] != sU.min sS)
          else: (if not doY: mX+=1); (if not doX: mY+=1); (resize; sizeHints())
          doClr
        of XK_minus, XK_KP_Subtract:            # '-' in all 3 modes
          if doS: S[] -= uint16(S[] != sU.min sS)
          else: (if not doY: mX-=1); (if not doX: mY-=1); (resize; sizeHints())
          mX = mX.max 1; mY = mY.max 1; doClr   # Keep m[XY] >= 1
        of XK_g:(if   doX:(gO[0]=gS[0]-gO[0];if gO[0] notin [gS[0], 0]: gO[0]=0)
                 elif doY:(gO[1]=gS[1]-gO[1];if gO[1] notin [gS[1], 0]: gO[1]=0)
                 else: (gO[0] = gS[0] - gO[0]; gO[1] = gS[1] - gO[1]); doClr)
        of XK_b: Box=not Box;(if Box:d.XMapWindow wB else:d.XUnmapWindow wB); pc
        of XK_c: Chase = not Chase; dty = true; pc
        of XK_p: pc
        of XK_h: doH = not doH; dty = true
        of XK_q: d.XCloseDisplay; quit &"{nR} frames read; {nW} written",0
        of XK_Shift_L,XK_Shift_R,XK_Control_L,XK_Control_R,XK_Alt_L,XK_Alt_R:discard
        else: doH = true  # XQueryPointer tracks motion => MotionNotify unneeded
      else: discard                     # 8)MAIN ACTION GET + SCALE_COPY
    if shm: discard d.XShmGetImage(s.root,im[I],iX,iY,AllPlanes) #discard=NimWTF
    else: d.XGetSubImage s.root, iX,iY, W[I],H[I], AllPlanes,ZPixmap, im[I],0,0
    let h = toOa[byte](im[I].data, 0, im[I].bytes.int - 1).hash
    if dty or h != hsh0:                # Need to upscale & write this frame
      dB.upScl cast[pua byte](im[O].data), cast[pua byte](im[I].data)
      if shm: d.XShmPutImage w, gc, im[O], 0, 0, 0, 0, W[O], H[O], 0
      else  : d.XPutImage w, gc, im[O], 0, 0, 0, 0, W[O], H[O]
      if doH and not hf.isNil:          # Maybe draw On-Screen Help
        for j,m in osh: d.XDrawString w,xc,0,cint(fH*(j+1)),m.cstring,m.len.cint
      dty = false; inc nW
    hsh0 = h
# CLI Gen Help/Controls; NOTE Highlight All Section Labels With rx'# [0-9])'
when isMainModule: import cligen; include cligen/mergeCfgEnv; dispatch xm,help={
  "display"  : "X11 display to use; `$DISPLAY` also works",
  "net"      : "force network graphics, not X11 Shm",
  "font"     : "font for on-screen help; \"\" => none",
  "fontH"    : "height in pixels of font for on-screen help",
  "xmag"     : "zoom of input-x axis", "ymag": "zoom of input-y axis",
  "unshifted": "step size for unshifted *[C,A]*-Arrows",
  "shifted"  : "step size for shifted *[C,A]*-Arrows",
  "outG"     : "WxH+x+y X Geom of output win; \"\"->WM placed",
  "inG"      : "inG win geom; \"\"->256x256;Size overrides -o",
  "gHS": "Grid Horizontal line Spacing", "gHO": "Grid Horizontal line Offset",
  "gVS": "Grid Vertical line Spacing"  , "gVO": "Grid Vertical line Offset"  ,
  "box"      : "toggle drawing xor-bounding box(zoomed area)",
  "BWidth"   : "BBox Border Width in pixels",
  "BColor"   : "BBox Border Color as 0xRRGGBB",
  "chase"    : "toggle chasing pointer to move zoomed area",
  "time"     : "extra delay between frames in microseconds",
  "watch"    : "if st_mtime(THIS path) changes, toggle chase"},
  short={"gHS": '\0', "gHO": '\0', "gVS": '\0', "gVO": '\0'}  # Force --gHS=..
