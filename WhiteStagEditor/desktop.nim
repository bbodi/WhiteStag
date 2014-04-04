import view
import frame
import color
import drawbuffer
import event
import pixel
import sdlengine
import option
import rect
import helpline
import dialog
import textfield


type

  PApplication* = ref TApplication
  TApplication* = object of TObject

  PDesktop* = ref TDesktop
  TDesktop = object of TView
    helpline: PHelpLine
    app: PApplication
    

method handleEvent*(self: PApplication, event: PEvent) = discard

method name*(self: PDesktop): string = "Desktop"

method handleEvent*(self: PDesktop, event: PEvent) = 
  self.app.handleEvent(event)
  case event.kind:
  of TEventKind.eventCommand:
    if event.cmd == cmdQuit:
      self.stopExecuting(cmdCancel)
  of TEventKind.eventWindowResized:
    let newSize = self.makeLocal(event.newWidth, event.newHeight)
    echo(repr(newSize))
    self.setWidthHeight(newSize.x, newSize.y)
    self.modified()
  else:
    discard

method draw*(self: PDesktop): TDrawBuffer = 
  engine.clear()

proc showStringDialog*(self: PDesktop, title: string, defaultText: string = ""): string =
  let w = self.w div 3
  let dialog = createDialogOkCancel(title, w, 4)
  let textField = createTextField(w - 4)
  textField.text = defaultText
  dialog.addViewAtCenterX(textField, 2)
  let dialogResult = self.showDialog(dialog)
  if dialogResult.cmd != cmdOk:
    return nil
  var data: string
  dialog.groupWriteDataTo(data)
  return data

proc createDesktop*(app: PApplication, w, h: int, fontSize: int): PDesktop = 
  if engine == nil:
    engine = sdlengine.init(w, h, fontSize)
  result = TDesktop.new
  result.setWidthHeight(w, h)
  result.font = some(engine.loadFont(fontSize))
  let helpline = createHelpLine(w)
  result.addView(helpline, 0, h - helpline.h)
  result.app = app

when isMainModule:
  import unittest

  test "inheritance":
    let view: PView = createDesktop(nil, 0, 0, 0)
    discard view.draw()
    check "Desktop" == view.name