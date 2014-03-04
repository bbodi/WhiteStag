import unicode
import streams

import view
import frame
import color
import drawbuffer
import event
import option
import sdlengine
import rect

type
  PButton* = ref TButton
  TButton* = object of TView
    label*: string
    cmd: TCmd
    disabled: bool
    pressed: bool


proc handleMouse(self: PButton, event: PEvent) =
  discard
    
method name*(self: PButton): string = "Button(" & self.label & ")"

method handleEvent*(self: PButton, event: PEvent) = 
  case event.kind:
  of TEventKind.eventMouseButtonDown:
    if event.local:
      self.pressed = true
      event.setProcessed()
      self.modified()
  of TEventKind.eventMouseButtonUp:
    if self.pressed:
      self.pressed = false
      self.modified()
      if event.local and not self.disabled:
        self.broadcastCommand(self.cmd, self)
      event.setProcessed()
  else:
    discard

method draw*(self: PButton): TDrawBuffer = 
  let styles = if self.isCurrentView: {styleBold} else: {styleNormal}
  self.buff.setCells(0, 0, self.w, self.h, bg = ButtonColor.color(self.disabled, self.pressed))
  self.buff.writeText(1, 0, self.label, styles = styles)
  return self.buff

proc createButton*(label: string, cmd: TCmd, disabled: bool = false): PButton = 
  result = new(TButton)
  result.setWidthHeight(label.runeLen + 2, 1)
  result.label = label
  result.disabled = disabled
  result.cmd = cmd

when isMainModule:
  import unittest
    
  test "inheritance":
    let view: PView = createButton("title", cmdOk)
    check "Button(title)" == view.name
    discard view.draw()

  test "buttons is as wide as its label":
    let view: PView = createButton("ékezetes betűk", cmdOk)
    check view.w == 14 + 2

  test "writeData":
    let view: PView = createButton("title", cmdOk)
    let stream = newStringStream()
    view.writeData(stream)
    check(stream.data == "")
    check(stream.getPosition == 0)

  test "readData":
    let view: PView = createButton("title", cmdOk)
    let stream = newStringStream()
    view.readData(stream)
    check(stream.data == "")
    check(stream.getPosition == 0)