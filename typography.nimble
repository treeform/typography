version       = "0.7.1"
author        = "treeform"
description   = "Fonts, Typesetting and Rasterization for Nim."
license       = "MIT"
srcDir        = "src"

requires "nim >= 1.0.0"
requires "pixie >= 0.0.9"
requires "vmath >= 0.4.0"
requires "chroma >= 0.1.2"
requires "print >= 0.1.0"
requires "bumpy >= 0.2.0"
requires "flatty >= 0.1.3"

task docs, "Generate API documents":
  exec "nimble doc --index:on --project --out:docs --hints:off src/typography.nim"
