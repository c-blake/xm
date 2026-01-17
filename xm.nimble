# Package
version     = "1.0.1"
author      = "Charles Blake"
description = "Nim rewrite of `xzoom` with many new features"
license     = "MIT/ISC"
installExt  = @[ "nim" ]
bin         = @[ "xm" ]

# Dependencies
requires "nim >= 2.2.0", "cligen >= 1.9.5"
