#include "sys/shm.h"              /* This is a separate header x11.nim uses. */
#include "X11/Xatom.h"            /* It is needed since XShm.h uses Bool, BUT*/
#include "X11/Xutil.h"            /* does not #include its C-level deps.  So,*/
#include "X11/extensions/XShm.h"  /* must enforce header order => Do our own.*/
#include "X11/extensions/shape.h" /* Maybe there is a cleaner way? */
#include "X11/XKBlib.h"
#define xClientDataAtom0(e) ((e).xclient.data.l[0])     /* Simplify x11.nim */
