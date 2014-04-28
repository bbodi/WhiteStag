import os
import streams

import ../WhiteStagEditor/window
import ../WhiteStagEditor/view
import ../WhiteStagEditor/pixel
import ../WhiteStagEditor/option
import ../WhiteStagEditor/desktop
import ../WhiteStagEditor/selectbox
import ../WhiteStagEditor/event
import ../WhiteStagEditor/scrollableViewWrapper
import ../WhiteStagEditor/scrollbar
import ../WhiteStagEditor/progressbar
import ../WhiteStagEditor/button
import ../WhiteStagEditor/radiogroup
import ../WhiteStagEditor/checkboxgroup
import ../WhiteStagEditor/textfield
import ../WhiteStagEditor/tree
import ../WhiteStagEditor/stringtree
import ../WhiteStagEditor/dialog
import ../WhiteStagEditor/list
import ../WhiteStagEditor/textarea
import ../WhiteStagEditor/panel
import ../WhiteStagEditor/combobox
import ../WhiteStagEditor/utfstring
import ../WhiteStagEditor/label


type
  TDebbyApp* = object of TApplication
    


const
  #chooseTypeAndOrContainsCmd = TCmd("chooseTypeAndOrContainsCmd")
  W = 80
  H = 40


var sourceViewerWindow = createWindow(W - 5, H - 5, "Source file")
sourceViewerWindow.closeable = true
sourceViewerWindow.resizable = true
sourceViewerWindow.growMode = {}

var sourceTextArea = createTextArea(sourceViewerWindow.w-2, sourceViewerWindow.h-2)
sourceTextArea.showLineNumbers = true
sourceViewerWindow.addView(sourceTextArea, 1, 1)
sourceTextArea.loadText(newFileStream("agility.nim", TFileMode.fmRead))


var application = new(TDebbyApp)
var deskt = createDesktop(application, 80, 40, 20)
deskt.addViewAtCenter(sourceViewerWindow)


discard deskt.execute()

method handleEvent(self: ref TDebbyApp, event: PEvent) = 
  case event.kind:
  of TEventKind.eventKey:
    if event.pressedCtrl('h'):
      event.setProcessed()
  else:
    discard