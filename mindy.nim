import WhiteStagEditor/window
import WhiteStagEditor/sdlengine
import WhiteStagEditor/view
import WhiteStagEditor/pixel
import WhiteStagEditor/option
import WhiteStagEditor/desktop
import WhiteStagEditor/selectbox
import WhiteStagEditor/event
import WhiteStagEditor/scrollableViewWrapper
import WhiteStagEditor/scrollbar
import WhiteStagEditor/progressbar
import WhiteStagEditor/button
import WhiteStagEditor/radiogroup
import WhiteStagEditor/checkboxgroup
import WhiteStagEditor/textfield
import WhiteStagEditor/tree
import WhiteStagEditor/stringtree
import WhiteStagEditor/dialog
import WhiteStagEditor/list
import WhiteStagEditor/textarea

type
  TMindy* = object of TApplication

var usersMenu = createStringSelectBox("Balázs", false)
discard usersMenu.addItem("Bettina", cmdOk)
discard usersMenu.addItem("Béla", cmdOk)
discard usersMenu.addItem("Károly", cmdOk)
discard usersMenu.addItem("Józsi", cmdOk)

var questionEditorWindow = createWindow(55, 25, "Adding new question")
questionEditorWindow.closeable = false
questionEditorWindow.resizable = false
questionEditorWindow.growMode = {}
questionEditorWindow.addView(createTextArea(51, 10), 2, 1)

var menuWindow = createWindow(35, 10, "Projects")
menuWindow.closeable = false
menuWindow.resizable = false
menuWindow.growMode = {}

var application = new(TMindy)

var deskt = createDesktop(application, 60, 30, 16)
deskt.addViewAtCenter(menuWindow)

var switchUserButton = createButton("Felhasználó váltása", TCmd("switchUserButton"))
var startButton = createButton("Kezdés", TCmd("Start"))
var newButton = createButton("Új hozzáadása", TCmd("addNewQuestion"))
var editButton = createButton("Szerkesztés", TCmd("Start"))
var exitButton = createButton("Kilépés", cmdCancel)
menuWindow.addViewAtCenter(switchUserButton, -2)
menuWindow.addViewAtCenter(startButton, -1)
menuWindow.addViewAtCenter(newButton, 0)
menuWindow.addViewAtCenter(editButton, 1)
menuWindow.addViewAtCenter(exitButton, 2)

discard deskt.execute()

method handleEvent(self: ref TMindy, event: PEvent) = 
  case event.kind:
  of TEventKind.eventCommand:
    if event.cmd == TCmd("switchUserButton"):
      event.setProcessed()
      let result = menuWindow.executeView(usersMenu, switchUserButton.x + switchUserButton.w div 2, switchUserButton.y)
      if result.cmd == cmdCancel:
        return
      let resultNameString = cast[string](result.data)
      menuWindow.title = resultNameString
      menuWindow.modified()
    elif event.cmd == TCmd("addNewQuestion"):
      let result = deskt.executeView(questionEditorWindow, 0, 0)
  else:
    discard