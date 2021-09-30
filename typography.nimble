version       = "0.7.12"
author        = "Andre von Houck"
description   = "Fonts, Typesetting and Rasterization for Nim."
license       = "MIT"
srcDir        = "src"

requires "nim >= 1.4.0"
requires "pixie >= 2.0.2"
requires "vmath >= 1.0.0"
requires "chroma >= 0.2.3"
requires "print >= 0.1.0"
requires "bumpy >= 1.0.3"
requires "flatty >= 0.1.3"

task docs, "Generate API documents":
  exec "nimble doc --index:on --project --out:docs --hints:off src/typography.nim"
