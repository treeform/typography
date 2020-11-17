# Package

version       = "0.4.0"
author        = "treeform"
description   = "Fonts, Typesetting and Rasterization for Nim."
license       = "MIT"
srcDir        = "src"

# Dependencies

requires "nim >= 1.0.0"
requires "flippy >= 0.4.7"
requires "vmath >= 0.3.1"
requires "chroma >= 0.1.2"
requires "print >= 0.1.0"

task docs, "Generate API documents":
  exec "nimble doc --index:on --project --out:docs --hints:off src/typography.nim"
