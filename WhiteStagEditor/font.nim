import sdl_ttf

import pixel

type
  TFont* = object
    charWidth*, charHeight*: TPixel
    size*: int
    normalSdlFont*: PFont
    italicSdlFont*: PFont
    boldSdlFont*: PFont
    boldItalicSdlFont*: PFont