## Bare-bones SDL2 example
import sdl2

import typography, vmath, flippy, chroma, tables, times, unicode, hashes

discard sdl2.init(INIT_EVERYTHING)

var
  window: WindowPtr
  render: RendererPtr

window = createWindow("SDL Skeleton", 100, 100, 640,480, SDL_WINDOW_SHOWN)
render = createRenderer(window, -1, Renderer_Accelerated or Renderer_PresentVsync or Renderer_TargetTexture)

# load font
var font = readFontTtf("fonts/Moon Bold.otf")
font.size = 16
font.lineHeight = 20

var
  evt = sdl2.defaultEvent
  runGame = true

type GlyphKey = object
  rune: Rune
  size: float
  subPixelShift: float

proc hash(x: GlyphKey): Hash =
  hashData(unsafeAddr x, sizeOf x)

type GlyphEntry = object
  image: Image
  texture: TexturePtr
  glyphOffset: Vec2

var glyphCache = newTable[GlyphKey, GlyphEntry]()

proc texture(image: Image): TexturePtr =
  # convert a flippy image to a SDL texture
  const
    rmask = uint32 0x000000ff
    gmask = uint32 0x0000ff00
    bmask = uint32 0x00ff0000
    amask = uint32 0xff000000
  var serface = createRGBSurface(0, cint image.width, cint image.height, 32, rmask, gmask, bmask, amask)
  serface.pixels = addr image.data[0]
  var texture = render.createTextureFromSurface(serface)
  return texture



while runGame:
  while pollEvent(evt):
    if evt.kind == QuitEvent:
      runGame = false
      break

  render.setDrawColor 0,0,0,255
  render.clear

  let start = epochTime()

  when false:
    # draw a single letter
    font.size = 300
    font.lineHeight = 300
    var image = font.getGlyphImage("Q")
    var destRect = sdl2.rect(
      cint 0,
      cint 0,
      cint image.width,
      cint image.height
    )
    sdl2.copy(render, image.texture, nil, addr destRect)

  when false:
    # compute layout and draw full layout at once
    var layout = font.typeset("""
Two roads diverged in a yellow wood,
And sorry I could not travel both
And be one traveler, long I stood
And looked down one as far as I could
To where it bent in the undergrowth;""")

    # draw text at a layout
    var image = newImage(500, 100, 4)
    image.drawText(layout)

    var destRect = sdl2.rect(
      cint 0,
      cint 0,
      cint image.width,
      cint image.height
    )
    sdl2.copy(render, image.texture, nil, addr destRect)

  when false:
    # draw single letter as a SDL texture

    var layout = font.typeset("""
Two roads diverged in a yellow wood,
And sorry I could not travel both
And be one traveler, long I stood
And looked down one as far as I could
To where it bent in the undergrowth;""")

    for pos in layout:
      var font = pos.font
      if pos.character in font.glyphs:
        var glyph = font.glyphs[pos.character]
        var glyphOffset: Vec2
        let image = font.getGlyphImage(glyph, glyphOffset, subPixelShift=pos.subPixelShift)
        var destRect = sdl2.rect(
          cint pos.rect.x + glyphOffset.x,
          cint pos.rect.y + glyphOffset.y,
          cint image.width,
          cint image.height
        )
        sdl2.copy(render, image.texture, nil, addr destRect)

  when true:
    # draw single letter at a time caching the letters as SDL texture

    var layout = font.typeset("""
Two roads diverged in a yellow wood,
And sorry I could not travel both
And be one traveler, long I stood
And looked down one as far as I could
To where it bent in the undergrowth;""")

    for pos in layout:
      var font = pos.font
      if pos.character in font.glyphs:
        let key = GlyphKey(rune: pos.rune, size: font.size, subPixelShift: quantize(pos.subPixelShift, 10))

        if key notin glyphCache:
          var glyph = font.glyphs[pos.character]
          var glyphOffset: Vec2
          let image = font.getGlyphImage(glyph, glyphOffset, subPixelShift=quantize(pos.subPixelShift, 10))
          glyphCache[key] = GlyphEntry(
              image: image,
              texture: image.texture,
              glyphOffset: glyphOffset
          )
          echo "new", key

        let glyphEntry = glyphCache[key]
        var destRect = sdl2.rect(
          cint pos.rect.x + glyphEntry.glyphOffset.x,
          cint pos.rect.y + glyphEntry.glyphOffset.y,
          cint glyphEntry.image.width,
          cint glyphEntry.image.height
        )

        discard glyphEntry.texture.setTextureColorMod(255, 0, 0)
        sdl2.copy(render, glyphEntry.texture, nil, addr destRect)

  #echo epochTime() - start

  render.present

destroy render
destroy window
