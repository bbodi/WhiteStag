import view
import frame
import font
import color
import drawbuffer
import event
import option
import sdlengine
import selectbox
import rect
import pixel

type
  PPanel* = ref TPanel
  TPanel* = object of TView
    frame*: TWindowFrame


method name*(self: PPanel): string = 
  "Panel"


method handleEvent*(self: PPanel, event: PEvent) = 
  discard

method draw*(self: PPanel): TDrawBuffer = 
  self.frame.draw(self, self.buff)
  return self.buff

proc createPanel*(w, h: int): PPanel = 
  result = new(TPanel)
  result.frame = (title: "", hasBorder: false)
  result.minWidth = 2
  result.minHeight = 2
  result.growMode = gmGrowAsParent
  result.setWidthHeight(w, h)

when isMainModule:
  import unittest
  import streams

  test "inheritance":
    let view: PView = createPanel(0, 0)
    view.font = some(TFont(charWidth: TPixel(1), charHeight: TPixel(1)))
    discard view.draw()
    check view.name == "Panel"

    