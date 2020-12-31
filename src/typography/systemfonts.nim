## Utils for finding installed and system fonts.

import algorithm, os, strutils, font

const fontDirectories* =
  when defined(MacOSX):
    [
      "/System/Library/Fonts/",
      "/Library/Fonts/",
      getHomeDir() & "/Library/Fonts/"
    ]
  elif defined(windows):
    [
      r"C:\Windows\Fonts",
    ]
  else:
    # TODO: linux paths
    []

proc getSystemFonts*(): seq[string] =
  ## Get a list of all of the installed fonts.
  for fontDir in fontDirectories:
    for kind, path in walkDir(fontDir):
      if kind == pcFile and path.splitFile().ext in [".ttf", ".otf"]:
        result.add(path)
  sort(result)

proc findFont*(fontName: string): string =
  ## Find a font given a font name.
  for fontDir in fontDirectories:
    for kind, path in walkDir(fontDir):
      if path.splitFile().name.toLowerAscii() == fontName.toLowerAscii():
        return path
  raise newException(TypographyError, "Font " & fontName & " not found")

proc getSystemFontPath*(): string =
  ## Gets the path to the system font.
  ## * San Francisco on MacOS.
  ## * Arial on Windows.
  ## * Linux - not implemented.
  when defined(macOS):
    "/System/Library/Fonts/SFNSText.ttf"
  elif defined(windows):
    r"C:\Windows\Fonts\arial.ttf"
  # else defined(linux):
  #   TODO: go through these direcotires
  #   "~/.fonts/"
  #   "/usr/share/fonts/truetype/"
  #   "/usr/X11R6/lib/X11/fonts/ttfonts/"
  #   "/usr/X11R6/lib/X11/fonts/"
  #   "/usr/share/fonts/truetype/"
  else:
    ""

when isMainModule:
  echo getSystemFonts()
  echo findFont("Arial")
  echo getSystemFontPath()
