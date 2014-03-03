import view
import frame
import color
import drawbuffer
import event
import option
import sdlengine
import rect


type
  PScrollableViewWrapper* = ref TScrollableViewWrapper
  TScrollableViewWrapper* = object of TView
    verticalPos: int
    horizontalPos: int

method name*(self: PScrollableViewWrapper): string = "ScrollableViewWrapper"

method draw*(self: PScrollableViewWrapper): TDrawBuffer = 
  return self.buff

method onChangeSize*(self: PScrollableViewWrapper, deltaW, deltaH: int) = discard

method handleEvent*(self: PScrollableViewWrapper, event: PEvent) = 
  if event.kind == TEventKind.eventKey: 
    var modX = 0
    var modY = 0
    if event.key == TKey.KeyArrowDown and event.keyModifier.ctrl:
      inc modY
    elif event.key == TKey.KeyArrowUp and event.keyModifier.ctrl:
      dec modY
    elif event.key == TKey.KeyArrowLeft and event.keyModifier.ctrl:
      inc modX
    elif event.key == TKey.KeyArrowRight and event.keyModifier.ctrl:
      dec modX
    else:
      return
    self.modified()
    self.horizontalPos += modX
    self.verticalPos += modY
    for view in self.views:
      view.move(modX, modY)
    event.setProcessed()
    

proc createScrollableViewWrapper*(w, h: int): PScrollableViewWrapper = 
  result = new(TScrollableViewWrapper)
  result.setWidthHeight(w, h)
  result.useClipping = true
  result.buff = createDrawBuffer(0, 0)

when false:
  import unittest

  test "inheritance":
    let view: PView = createScrollableViewWrapper(0, 0, "title")
    discard view.draw()
    check view.name == "Window(title)"