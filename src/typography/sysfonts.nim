## Utils for finding installed and system fonts.

import os, strutils

var fontDirectories*: seq[string]

when defined(MacOSX):
  fontDirectories = @[
    "/System/Library/Fonts/",
    "/Library/Fonts/",
    getHomeDir() & "/Library/Fonts/"
  ]
elif defined(windows):
  fontDirectories = @[
    r"C:\Windows\Fonts",
  ]
else:
  # TODO implement linux
  discard

proc getSystemFonts*(): seq[string] =
  ## Get a list of all of the installed fonts.
  for fontDir in fontDirectories:
    for kind, path in walkDir(fontDir):
      result.add path

proc findFont*(fontName: string): string =
  ## Find a font given a font name.
  for fontDir in fontDirectories:
    for kind, path in walkDir(fontDir):
      let (dir, name, ext) = path.splitFile()
      if name.toLowerAscii() == fontName.toLowerAscii():
        return path

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
    return ""

when isMainModule:
  echo getSystemFonts()
  echo findFont("Arial")
  echo getSystemFontPath()
