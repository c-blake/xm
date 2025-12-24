{.passl: "-lX11 -lXext".}   # X11 & POSIX Shm Nim Decls; Link with: -lX11 -lXext
import os, macros, posix; export posix
const X = currentSourcePath.parentDir & "/x.h"
template prag(r) =
  r = def; r.addPragma ident"nodecl"; r.addPragma ident"importc"
  r.addPragma nnkExprColonExpr.newTree(ident"header", X.newLit)
macro C(def): untyped = prag(result)   # C) API and a D)iscardable variant
macro D(def): untyped = (prag(result); result.addPragma ident"discardable")
type                    # # X11 Core Types
  Visual*{.nodecl,importc,header:X,incompleteStruct.} = object
  Window*   = culong
  Font*     = culong
  Drawable* = culong
  Atom*     = culong
  GC*       = pointer
  Bool*     = cint
  Status*   = cint
  KeyCode*  = char
  KeySym*   = culong
  Display*{.nodecl,importc,header:X,incompleteStruct.} = object
  DisplayP = ptr Display
  Screen*{.nodecl,importc,header:X,incompleteStruct.} = object
    root*: Window       # Needed fields of Screen structure
    width*, height*, root_depth*: cint
    root_visual*: ptr Visual
    white_pixel*, black_pixel*: culong
  XFontStruct*{.nodecl,importc,header:X,incompleteStruct.} = object
    fid*: Font
    ascent*, descent*: cint
  XImage*{.nodecl,importc,header:X,incompleteStruct.} = object
    width*, height*, bytes_per_line*: cint # xoffset*, depth*
    data*: pointer
  XGCValues*{.nodecl,importc,header:X,incompleteStruct.} = object
    function*, subwindow_mode*: cint
    plane_mask*, foreground*, font*: culong
  XSetWindowAttributes*{.nodecl,importc,header:X,incompleteStruct.} = object
    override_redirect*: Bool
    background_pixel*: culong
    event_mask*: clong
  XSizeHints*{.nodecl,importc,header:X,incompleteStruct.} = object
    flags*: clong
    min_width*, min_height*, width_inc*, height_inc*: cint
  XKeyEvent*{.nodecl,importc,header:X,incompleteStruct.} = object
    state*: cuint
    keycode*: KeyCode
  XRectangle*{.nodecl,importc,header:X,incompleteStruct.} = object
    x*, y*: cshort
    width*, height*: cushort
  XClientMessageEvent*{.nodecl,importc,header:X,incompleteStruct.} = object
    message_type*: Atom #data*{.importc:"data".}:array[20,byte]#l[5]|s[10]|b[20]
  XConfigureEvent*{.nodecl,importc,incompleteStruct.} = object
    width*, height*: cuint
  XEvent*{.nodecl,importc,header:X,union,incompleteStruct.} = object
    eType*{.importc: "type".}: cint   # XEvent union w/all major event types
    xkey*: XKeyEvent
    xclient*: XClientMessageEvent
    xconfigure*: XConfigureEvent
  XErrorEvent*{.nodecl,importc,header:X,incompleteStruct.} = object
    resourceid*: culong
    error_code*, request_code*, minor_code*: uint8
  XErrorHandler* = proc(dp: DisplayP, event: ptr XErrorEvent): cint{.cdecl.}

const                   # # X11 Constants
  ZPixmap*             = 2              # Image format
  InputOutput*         = 1              # Window class
  KeyPressMask*        = 1 shl 0        # Event Masks/Numbers
  StructureNotifyMask* = 1 shl 17 
  KeyPress*            =  2
  MotionNotify*        =  6
  ConfigureNotify*     = 22
  ClientMessage*       = 33
  XK_plus*             = 0x002b         # Keysyms
  XK_minus*            = 0x002d
  XK_equal*            = 0x003d
  XK_b*                = 0x0062
  XK_c*                = 0x0063
  XK_g*                = 0x0067
  XK_h*                = 0x0068
  XK_p*                = 0x0070
  XK_q*                = 0x0071
  XK_s*                = 0x0073
  XK_x*                = 0x0078
  XK_y*                = 0x0079
  XK_Left*             = 0xff51
  XK_Up*               = 0xff52
  XK_Right*            = 0xff53
  XK_Down*             = 0xff54
  XK_KP_Left*          = 0xff96
  XK_KP_Up*            = 0xff97
  XK_KP_Right*         = 0xff98
  XK_KP_Down*          = 0xff99
  XK_KP_Add*           = 0xffab
  XK_KP_Subtract*      = 0xffad
  XK_Shift_L*          = 0xffe1
  XK_Shift_R*          = 0xffe2
  XK_Control_L*        = 0xffe3
  XK_Control_R*        = 0xffe4
  XK_Alt_L*            = 0xffe9
  XK_Alt_R*            = 0xffea
  ShiftMask*           = 1 shl  0       # Lock = shl 1
  ControlMask*         = 1 shl  2
  AltMask*             = 1 shl  3       # NOTE X11 calls this "Mod1"
  CWBackPixel*         = 1 shl  1       # Window attribute masks
  CWOverrideRedirect*  = 1 shl  9
  CWEventMask*         = 1 shl 11
  GCFunction*          = 1 shl  0       # GC component masks
  GCPlaneMask*         = 1 shl  1
  GCForeground*        = 1 shl  2
  GCFont*              = 1 shl 14
  GCSubwindowMode*     = 1 shl 15
  GXcopy*              = 0x3            # GC functions
  GXxor*               = 0x6
  IncludeInferiors*    = 1              # Subwindow modes
  AllPlanes*: culong   = not 0'u64
  PropModeReplace*     = 0              # Property modes
  XA_STRING*           = 31.Atom        # Standard Atoms aka Interned Strings
  XA_WM_NAME*          = 39.Atom
  XA_WM_NORMAL_HINTS*  = 40.Atom
  XValue*              = 1 shl 0        # XParseGeometry Mask Constants
  YValue*              = 1 shl 1
  XNegative*           = 1 shl 4
  YNegative*           = 1 shl 5
  PMinSize*            = 1 shl 4        # For XSetWMSizeHints
  PResizeInc*          = 1 shl 6
                        # # X11 Core declarations
using dp:DisplayP;using w:Window;using gc:GC;using atrs:ptr XSetWindowAttributes
proc XkbKeycodeToKeysym*(dp; kc: KeyCode; grp,lvl: cuint): KeySym{.C.}
proc XOpenDisplay*(displayName: cstring): DisplayP{.C.}
proc XCloseDisplay*(dp): cint{.D.}
proc DefaultScreenOfDisplay*(dp): ptr Screen{.C.}
proc BitmapUnit*(dp): cuint{.C.}
proc XScreenCount*(dp): cint{.C.}
proc XRootWindow*(dp; screenNumber: cint): Window{.C.}
proc XCreateWindow*(dp; par: Window; x,y: cint; W,H,bordW: cuint; depth: cint,
       class: cuint, vis: ptr Visual; valMsk: culong; atrs): Window{.C.}
proc XMapWindow*(dp; w): cint{.D.}
proc XUnmapWindow*(dp; w): cint{.D.}
proc XResizeWindow*(dp; w; W,H: cuint): cint{.D.}
proc XMoveResizeWindow*(dp; w; x,y: cint; W,H: cuint): cint {.D.}
proc XRaiseWindow*(dp; w): cint {.D.}
proc XCreateGC*(dp; d: Drawable,valMsk: culong,vals: ptr XGCValues): GC{.C.}
proc XLoadQueryFont*(dp; name: cstring): ptr XFontStruct{.C.}
proc XPending*(dp): cint{.C.}
proc XNextEvent*(dp; eventRet: ptr XEvent): cint{.D.}
proc XQueryPointer*(dp; w; root,kid: ptr Window; rX,rY,wX,wY: ptr cint;
       msk: ptr cuint): Bool{.C.}
proc XDrawString*(dp; d: Drawable; gc; x,y: cint; s:cstring; n:cint): cint {.D.}
proc XPutImage*(dp; d: Drawable; gc; im: ptr XImage; srcX,srcY,dstX,dstY: cint;
       W,H: cuint): cint{.D.}
proc XGetSubImage*(dp; d: Drawable; x,y: cint; W,H: cuint, planeMsk: culong,
       fmt: cint, dstIm: ptr XImage; dstX,dstY: cint): ptr XImage{.D.}
proc XCreateImage*(dp; vis: ptr Visual; depth,fmt,offset: cint; data: pointer;
       W,H: cuint; bitmapPad,bytesPerLine: cint): ptr XImage{.C.}
proc XInitImage*(im: ptr XImage): Status{.D.}
proc XDestroyImage*(ximage: ptr XImage): cint{.D.}
proc XChangeProperty*(dp; w; prop,kind: Atom; fmt,mode: cint; data: pointer;
       n: cint): cint{.D.}
proc XInternAtom*(dp; atomName: cstring, onlyIfExists: Bool): Atom{.C.}
proc XSetWMProtocols*(dp; w; protos: ptr Atom,count: cint): Status{.D.}
proc XParseGeometry*(s: cstring; x, y: ptr cint; W, H: ptr cuint): cint{.C.}
proc XSetErrorHandler*(handler: XErrorHandler): XErrorHandler{.D.}
proc xClientDataAtom0*(e: XEvent): Atom{.C.} #NOTE Defined in "xmpkg/x.h" itself
proc XAllocSizeHints*(): ptr XSizeHints{.C.}
proc XSetWMSizeHints*(dp; w; hints: ptr XSizeHints, property: Atom) {.D.}
proc XShapeCombineRectangles*(dp; dst: Drawable; dstKind,xOff,yOff: cint;
                              rects:ptr XRectangle; nRect,op,order: cint) {.C.}
type key_t* = cint      # # POSIX ShmTypes,Funcs; Should be in stdlib like IPC_*
type shmatt_t* = cushort
proc shmget*(key: key_t, size: csize_t, shmflg: cint): cint{.C.}
proc shmat*(shmid: cint, shmaddr: pointer, shmflg: cint): pointer{.C.}
proc shmdt*(shmaddr: pointer): cint{.D.}
proc shmctl*(shmid, cmd: cint; buf: pointer): cint{.D.}
proc XQueryExtension*(dp; nm: cstring; majOpCode,ev0,err0: ptr cint): Bool{.C.}
type XShmSegmentInfo*{.nodecl,importc,header:X.} = object
    shmid*: cint        # # X11 Shared Memory Extension Types & Procs
    shmaddr*: pointer
    readOnly*: Bool
proc XShmCreateImage*(dp; vis: ptr Visual; depth,fmt: cint; data: cstring,
                      si: ptr XShmSegmentInfo; W,H: cuint): ptr XImage{.C.}
proc XShmAttach*(dp; si: ptr XShmSegmentInfo): Bool{.C.}
proc XShmDetach*(dp; si: ptr XShmSegmentInfo): Bool{.D.}
proc XShmGetImage*(dp;d:Drawable;im:ptr XImage;x,y:cint; plMsk:culong):Bool{.D.}
proc XShmPutImage*(dp;d: Drawable;gc; im: ptr XImage; srcX,srcY,dstX,dstY: cint;
                   W,H: cuint; sendEv: Bool): Bool{.D.}
