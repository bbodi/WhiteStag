import view
import frame
import color
import drawbuffer
import event
import pixel
import option
import rect
import helpline
import dialog
import textfield
import utfstring


type
  PLabel* = ref TLabel
  TLabel = object of TView
    text: PUTFString
    

method name*(self: PLabel): string = "Label"

method handleEvent*(self: PLabel, event: PEvent) = 
  discard

method draw*(self: PLabel): TDrawBuffer = 
  self.buff.writeText(0, 0, $self.text)
  return self.buff

proc createLabel*(text: PUTFString): PLabel = 
  result = new TLabel
  result.text = text
  result.setWidthHeight(text.len, 1)

proc createLabel*(text: string): PLabel = 
  result = createLabel(newString(text))

when isMainModule:
  import unittest

  test "inheritance":
    let view: PView = createLabel("label text")
    discard view.draw()
    check "Label" == view.name