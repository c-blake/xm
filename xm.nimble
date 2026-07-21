# Package
version     = "1.2.0"
author      = "Charles Blake"
description = "Nim rewrite of `xzoom` with many new features"
license     = "MIT/ISC"
installExt  = @[ "nim" ]
bin         = @[ "xm", "xmpkg/xrd" ]

# Dependencies
requires "nim >= 2.2.0", "cligen >= 1.11.0"
