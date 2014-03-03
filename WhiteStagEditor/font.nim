import sdl_ttf

import pixel

type
  TFont* = object
    charWidth*, charHeight*: TPixel
    size*: int
    sdlFont*: PFont