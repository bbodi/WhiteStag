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

type
  TMindy* = object of TApplication

var menuWindow = createWindow(20, 30, "Projects")
menuWindow.closeable = false
menuWindow.resizable = false
menuWindow.growMode = {}

var application = new(TMindy)

var deskt = createDesktop(application, 40, 30, 16)
deskt.addViewAtCenter(menuWindow)

var startButton = createButton("Kezdés", TCmd("Start"))
var newButton = createButton("Új hozzáadása", TCmd("Start"))
var editButton = createButton("Szerkesztés", TCmd("Start"))
var exitButton = createButton("Kilépés", TCmd("Start"))
menuWindow.addViewAtCenter(startButton, 1)
menuWindow.addViewAtCenter(newButton, 2)
menuWindow.addViewAtCenter(editButton, 3)
menuWindow.addViewAtCenter(exitButton, 4)

discard deskt.execute()