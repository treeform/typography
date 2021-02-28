import os, algorithm, pixie, chroma

proc findAllFonts*(rootPath: string): seq[string] =
  for fontPath in walkDirRec(rootPath):
    if splitFile(fontPath).ext in [".ttf", ".otf"]:
      result.add(fontPath)
  result.sort()

proc imageDiff*(master, image: Image): (float32, Image) =
  var
    diffImage = newImage(master.width, master.height)
    diffScore = 0
    diffTotal = 0
  for x in 0 ..< master.width:
    for y in 0 ..< master.height:
      let
        m = master.getRgbaUnsafe(x, y)
        u = image.getRgbaUnsafe(x, y)
        diff = (m.r.int - u.r.int) +
          (m.g.int - u.g.int) +
          (m.b.int - u.b.int)
      var c: ColorRGBA
      c.r = abs(m.a.int - u.a.int).clamp(0, 255).uint8
      c.g = (diff).clamp(0, 255).uint8
      c.b = (-diff).clamp(0, 255).uint8
      c.a = 255
      diffScore += abs(m.r.int - u.r.int) +
        abs(m.g.int - u.g.int) +
        abs(m.b.int - u.b.int) +
        abs(m.a.int - u.a.int)
      diffTotal += 255 * 4
      diffImage.setRgbaUnsafe(x, y, c)
  return (100 * diffScore.float32 / diffTotal.float32, diffImage)

proc strokeRectInner*(image: Image, rect: Rect, rgba: ColorRGBA) =
  ## Draws a rectangle borders only.
  let
    at = rect.xy.floor + vec2(0.5, 0.5)
    wh = rect.wh.floor - vec2(1, 1) # line width
  image.strokeRect(rect(at, wh), rgba)
