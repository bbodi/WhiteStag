import unicode

import view
import frame
import color
import drawbuffer
import event
import option
import sdlengine
import rect
import pixel


type
  PHelpLine* = ref THelpLine
  THelpLine* = object of TView
    mouseX, mouseY: int

    
method name*(self: PHelpLine): string = "HelpLine"

method handleEvent*(self: PHelpLine, event: PEvent) = 
  case event.kind:
  of TEventKind.eventMouseMove, TEventKind.eventMouseButtonUp:
    self.mouseX = event.mouseX div self.font.charWidth
    self.mouseY = event.mouseY div self.font.charHeight
  else:
    discard

method draw*(self: PHelpLine): TDrawBuffer = 
  self.buff.setCells(0, 0, self.w, self.h, bg = BackgroundColor.first)
  self.buff.writeText(0, 0, $self.mouseX & ", " & $self.mouseY)
  return self.buff

proc createHelpLine*(width: int): PHelpLine = 
  result = new(THelpLine)
  result.setWidthHeight(width, 2)


when isMainModule:
  import unittest
    
  test "inheritance":
    let view: PView = createHelpLine(10)
    check "HelpLine" == view.name
    discard view.draw()