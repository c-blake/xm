import std/[syncio,formatFloat,strformat,hashes,times], x # 0) IMPORTS&GLOBALS
template E(a: varargs[untyped]) = stderr.write a, "\n"    # echo but ->stderr

var d: ptr Display; var s: ptr Screen   # X11 & CLI Globals
var iX, iY, shmOp, ev0, er0: cint       # Upper Left of I; XShm
var shm, warm: bool                     # Flags shm; Status have real Hash yet
var W, H: cuint
var si: XShmSegmentInfo
var im: ptr XImage

proc bytes(imP: ptr XImage): csize_t = csize_t(imP.bytes_per_line*imP.height)
proc imgsMake() =               # 1) SHARED MEMORY S)EGMENT I)NFO
  if shm:
    if (im = d.XShmCreateImage(s.root_visual, s.root_depth, ZPixmap, nil,
                                  si.addr, W, H); im.isNil):
      quit "XShmCreateImage: " & $errno.strerror,5
    si.shmid = shmget(IPC_PRIVATE, im.bytes, IPC_CREAT or 0o777)
    if si.shmid < 0: quit "shmget: " & $errno.strerror,6
    si.shmaddr = cast[pointer](shmat(si.shmid, nil, 0))
    if si.shmaddr == cast[pointer](-1): quit "shmat: " & $errno.strerror,7
    im.data = si.shmaddr        # XSync here might fix races &so silence errs..
    si.readOnly = 0             #..but also cost & unsure frames even drop.
    if d.XShmAttach(si.addr) == 0: quit "XShmAttach: " & $errno.strerror,8
    shmctl si.shmid, IPC_RMID, nil
  else:
    if (im=d.XCreateImage(s.root_visual, s.root_depth, ZPixmap, 0,
                          alloc(W*H*d.BitmapUnit div 8), W,H, 32,0); im.isNil):
            quit "XCreateImage: " & $errno.strerror,9
    XInitImage im

proc badGeom(str: string; x,y: var cint; w,h: var cuint): bool =
  let m = str.cstring.XParseGeometry(x.addr, y.addr, w.addr, h.addr)
  if m == 0: return true
  if (m and XValue) != 0 and (m and XNegative) != 0: x += s.width
  if (m and YValue) != 0 and (m and YNegative) != 0: y += s.height

proc xErr(_: ptr Display; e: ptr XErrorEvent): cint{.cdecl.} = # FastOps ~ Racy
  if e.request_code.cint==shmOp and e.minor_code.int in[1,2]:return#X_ShmDAttach
  if e.request_code.cint==shmOp and e.minor_code.int in[3,4]:
    E &"MIT-SHM extension present, but ops fail => network transparent mode"
    shm = false; imgsMake(); return     # imgsFree() not needed
  E &"rq={e.request_code}.{e.minor_code} res={e.resourceid:x} e={e.error_code}"

proc stop(Hash, h, hsh0: Hash): bool =
  if Hash != 0 and h == Hash: return true           # Changed to nz target hash
  if Hash == 0 and warm and h != hsh0: return true  # Changed from initial

template pua(T: typedesc): untyped = ptr UncheckedArray[T]
template toOa[T](p:pointer;a,b:int):untyped = toOpenArray[T](cast[pua T](p),a,b)
proc xrd(display="", net=false, inG="8x8+0+0", Hash=0, verb=false, time=40_000) =
  ## Grab root frame buffer rectangles @`time`-driven rate & print time & exit
  ## as soon as Rectangle Hash Differs across a frame.
  d = nil.XOpenDisplay; if d.isNil: quit "Cannot open display",1
  s = d.DefaultScreenOfDisplay
  shm=(not net) and d.XQueryExtension("MIT-SHM",shmOp.addr,ev0.addr,er0.addr)!=0
  if inG.badGeom(iX, iY, W, H): quit "bad iGeom: " & inG, 2
  imgsMake()
  XSetErrorHandler xErr
  var hsh0: Hash; var nFrame = 0
  let t0 = epochTime()
  while time==0 or usleep(time.Useconds)==0:    # MAIN LOOP CONDITION
    if shm: discard d.XShmGetImage(s.root, im, iX, iY, AllPlanes) #NimWTFdiscard
    else: d.XGetSubImage s.root, iX, iY, W, H, AllPlanes, ZPixmap, im, 0, 0
    let h = toOa[byte](im.data, 0, im.bytes.int - 1).hash
    if verb: stderr.write &"{epochTime():.9f} Hash: {h}\n"
    if stop(Hash, h, hsh0):
      let t1 = epochTime()
      echo &"{t1:.9f} {(t1 - t0)/nFrame.float:.9f} sec/frame_amortized"
      quit 0
    hsh0 = h; warm = true
    inc nFrame # Late bump so in echo above number of inter-frame time intervals

when isMainModule: import cligen;include cligen/mergeCfgEnv; dispatch xrd,help={
  "display": "X11 display to use; `$DISPLAY` also works",
  "net"    : "force network graphics, not X11 Shm",
  "inG"    : "input rectangle X win geometry",
  "Hash"   : "exit when Hash value becomes this",
  "verb"   : "Print final Hash value of area to stderr",
  "time"   : "extra delay between frames in microseconds"}
