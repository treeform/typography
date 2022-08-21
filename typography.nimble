version       = "0.7.14"
author        = "Andre von Houck"
description   = "Fonts, Typesetting and Rasterization for Nim."
license       = "MIT"
srcDir        = "src"

requires "nim >= 1.4.0"
requires "pixie >= 5.0.1"
requires "print >= 0.1.0"

task docs, "Generate API documents":
  exec "nimble doc --index:on --project --out:docs --hints:off src/typography.nim"
