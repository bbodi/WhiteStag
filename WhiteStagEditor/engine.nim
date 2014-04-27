import pixel
import drawbuffer
import rect
import color
import font
import event

type
  TEngine = object of TObject

method isInitialized*(self: ref TEngine): bool = quit "to override!"
method clear*(self: ref TEngine) = quit "to override!"
method loadFont*(self: ref TEngine, size: int, name: string = "DejaVuSansMono"): TFont = quit "to override!"
method init*(self: ref TEngine, w, h: int, fontSize: int): ref TEngine = quit "to override!"
method swapBackBuffer*(self: ref TEngine) = quit "to override!"
method pollEvent*(self: ref TEngine): event.PEvent = quit "to override!"
method readClipBoard*(self: ref TEngine): PUTFString = quit "to override!"
method drawToBackBuffer*(self: ref TEngine, buff: TDrawBuffer, offsetX, offsetY: TPixel, font: TFont, clippingArea: TPixelRect) = quit "to override!"
  