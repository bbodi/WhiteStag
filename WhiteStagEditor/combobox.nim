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
  PComboBox*[T] = ref TComboBox[T]
  TComboBox*[T] = object of TView
    selectbox*: PSelectBox[T]
    frame: TWindowFrame
    data*: T
    defaultTitle*: string

proc setSize*[T](self: PComboBox[T]) =
  let w = 
    if not self.data.isNil:
      self.selectbox.getItemWidth(self.data) + 2
    else:
      self.defaultTitle.len + 2
  self.setWidthHeight(w, 1)

proc drawSelectedItemToBuffer*[T](self: PComboBox[T]) =
  self.setSize()
  self.buff.clear()
  self.frame.draw(self, self.buff)
  if self.data.isNil:
    self.buff.writeText(1, 0, self.defaultTitle & "↓")
  else:
    self.selectbox.drawItemTo(self.data, self.buff)
    self.buff.writeText(self.buff.w-1, 0, "↓")


proc open[T](self: PComboBox[T]) =
  let parentY2 = self.owner.expect("combobox must have a parent when it is drawn").realY2
  var y = 1
  if parentY2 < self.realY + self.selectbox.h:
    y = -self.selectbox.h
  let result = self.executeView(self.selectbox, 3, y)
  self.data = cast[pointer](result.data)
  self.drawSelectedItemToBuffer()
  if result.cmd != cmdOk:
    self.broadcastCommand(result.cmd, result.data)

proc handleKey*[T](self: PComboBox[T], event: PEvent) =
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
    
method name*[T](self: PComboBox[T]): string = "ComboBox"


method handleEvent*[T](self: PComboBox[T], event: PEvent) = 
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

method draw*[T](self: PComboBox[T]): TDrawBuffer = 
  return self.buff

proc createComboBox*[T](defaultTitle: string, selectbox: PSelectBox[T]): PComboBox[T] = 
  result = new(TComboBox[T])
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
