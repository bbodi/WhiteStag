import "../font"
import "../pixel"
import "../drawbuffer"
import "../rect"
import "../color"
import "../event"
import "../utfstring"

type
  #TPassOpen = proc (module: PSym): PPassContext {.nimcall.}
  TInit = proc(w, h: int, fontSize: int)
  TClearScreen = proc()
  TLoadFont = proc(size: int, name: string = "DejaVuSansMono"): TFont
  TSwapBackBuffer = proc()
  TPollEvent = proc(): PEvent
  TReadClipBoard = proc(): PUTFString
  TDrawToBackBuffer = proc(buff: TDrawBuffer, offsetX, offsetY: TPixel, font: TFont, clippingArea: TPixelRect)

  TEngine* = object
    initialized*: bool
    init*: TInit
    clearScreen*: TClearScreen
    loadFont*: TLoadFont
    swapBackBuffer*: TSwapBackBuffer
    pollEvent*: TPollEvent
    readClipBoard*: TReadClipBoard
    drawToBackBuffer*: TDrawToBackBuffer
