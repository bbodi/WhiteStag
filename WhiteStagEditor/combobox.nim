import unicode

import view
import frame
import color
import drawbuffer
import event
import option
import sdlengine
import rect
import selectbox
import utfstring


type
  PComboBox* = ref TComboBox
  TComboBox* = object of TView
    selectbox*: PSelectBox
    frame: TWindowFrame
    data*: PUTFString
    defaultTitle*: string

proc setSize*(self: PComboBox) =
  let w = 
    if not self.data.isNil:
      self.selectbox.getItemWidth(self.data) + 2
    else:
      self.defaultTitle.len + 2
  self.setWidthHeight(w, 1)

proc drawSelectedItemToBuffer(self: PComboBox) =
  self.setSize()
  self.buff.clear()
  self.frame.draw(self, self.buff)
  if self.data.isNil:
    self.buff.writeText(1, 0, self.defaultTitle & "↓")
  else:
    self.selectbox.drawItemTo(self.data, self.buff)
    self.buff.writeText(self.buff.w-1, 0, "↓")


proc open(self: PComboBox) =
  let result = self.executeView(self.selectbox, 3, 1)
  self.data = cast[PUTFString](result.data)
  self.drawSelectedItemToBuffer()
  if result.cmd != cmdOk:
    self.broadcastCommand(result.cmd, result.data)

proc close(self: PComboBox) =
  discard

proc handleKey*(self: PComboBox, event: PEvent) =
  case event.key:
  of TKey.KeyArrowDown:
    self.open()
    event.setProcessed()
  of TKey.KeyArrowUp:
    self.open()
    event.setProcessed()
  of TKey.KeyEnter:
    self.open()
    event.setProcessed()
  else:
    discard
    
method name(self: PComboBox): string = "ComboBox"


method handleEvent(self: PComboBox, event: PEvent) = 
  case event.kind:
  of TEventKind.eventMouseButtonDown:
    if event.local:
      self.open()
      self.modified()
      event.setProcessed()
  of TEventKind.eventKey:
    self.handleKey(event)
  else:
    discard

method draw(self: PComboBox): TDrawBuffer = 
  return self.buff

proc createComboBox*(defaultTitle: string, selectbox: PSelectBox): PComboBox = 
  result = new(TComboBox)
  result.defaultTitle = defaultTitle
  result.selectbox = selectbox
  result.frame = (title: nil, hasBorder: false)
  result.setSize()
  result.drawSelectedItemToBuffer()


when isMainModule:
  import unittest

  suite "combobox":

    setup:
      discard

    test "":
      discard
