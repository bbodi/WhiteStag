import view
import frame
import color
import drawbuffer
import event
import option
import rect
import button
import window

type
  PDialog* = ref TDialog
  TDialog* = object of TWindow
    okBtn, cancelBtn: PButton

method name*(self: PDialog): string = "Dialog" & "(" & self.frame.title & ")"

method draw*(self: PDialog): TDrawBuffer = 
  return drawWindow(self)

method handleEvent*(self: PDialog, event: PEvent) = 
  case event.kind:
  of TEventKind.eventKey: 
    if event.key == TKey.KeyEnter:
      self.stopExecuting(cmdOk)
      event.setProcessed()
    elif event.key == TKey.KeyEsc:
      self.stopExecuting(cmdCancel)
      event.setProcessed()
  of TEventKind.eventCommand:
    if event.cmd == cmdOk and event.isFrom(self.okBtn):
      self.stopExecuting(cmdOk)
      event.setProcessed()
    elif event.cmd == cmdCancel and event.isFrom(self.cancelBtn):
      self.stopExecuting(cmdCancel)
      event.setProcessed()
  of TEventKind.eventGetFocus:
    let dialogJustOpened = event.sourceViewEquals(self)
    if dialogJustOpened:
      let lastView = self.topView.expect("Dialog must cotnains at least one View!")
      lastView.setFocused()
  else:
    discard
  windowHandleEvent(self, event)

proc addButtonsRow(self: PDialog, buttons: openarray[PButton]) =
  var sumWidth = 0
  for button in buttons: 
    sumWidth += button.w
  let spaceBetweenButtons = 2
  let allSpacesBetweenButtons = (buttons.len-1) * spaceBetweenButtons
  sumWidth += allSpacesBetweenButtons
  var x = (self.w div 2) - (sumWidth div 2)
  let y = self.h - 2
  for button in buttons: 
    self.addView(button, x, y)
    x += button.w + spaceBetweenButtons

proc createDialog*(title: string, w, h: int, buttons: openarray[PButton]): PDialog = 
  result = new(TDialog)
  result.frame = (title: title, hasBorder: true)
  result.setWidthHeight(w, h+2)
  result.closeable = false
  result.resizable = false
  

proc createDialogOk*(title: string, w, h: int): PDialog = 
  result = createDialog(title, w, h, [])
  result.okBtn = createButton("Ok", cmdOk)
  result.addButtonsRow([result.okBtn])

proc createDialogOkCancel*(title: string, w, h: int): PDialog = 
  result = createDialog(title, w, h, [])
  result.okBtn = createButton("Ok", cmdOk)
  result.cancelBtn = createButton("Cancel", cmdCancel)
  result.addButtonsRow([result.okBtn, result.cancelBtn])

proc createDialogYesNo*(title: string, w, h: int): PDialog = 
  result = createDialog(title, w, h, [])
  result.okBtn = createButton("Yes", cmdOk)
  result.cancelBtn = createButton("No", cmdCancel)
  result.addButtonsRow([result.okBtn, result.cancelBtn])


proc showDialog*(self: PView, dialog: PDialog): TExecutingResult = self.executeViewAtCenter(dialog)

when isMainModule:
  import unittest
  import font
  import pixel

  test "inheritance":
    let view: PView = createDialogOk("title", 0, 0)
    view.font = some(TFont(charWidth: TPixel(1), charHeight: TPixel(1)))
    discard view.draw()
    check view.name == "Dialog(title)"