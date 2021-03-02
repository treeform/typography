import os, algorithm, pixie, chroma

proc findAllFonts*(rootPath: string): seq[string] =
  for fontPath in walkDirRec(rootPath):
    if splitFile(fontPath).ext in [".ttf", ".otf"]:
      result.add(fontPath)
  result.sort()

proc strokeRectInner*(image: Image, rect: Rect, rgba: ColorRGBA) =
  ## Draws a rectangle borders only.
  let
    at = rect.xy.floor + vec2(0.5, 0.5)
    wh = rect.wh.floor - vec2(1, 1) # line width
  image.strokeRect(rect(at, wh), rgba)
