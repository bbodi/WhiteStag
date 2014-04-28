import window
import view
import pixel
import option
import colors
import sdl_ttf
import desktop
import selectbox
import combobox
import event
import scrollableViewWrapper
import scrollbar
import progressbar
import button
import radiogroup
import checkboxgroup
import textfield
import tree
import stringtree

type
  TMain = object of TApplication

var mainApp = new(TMain)

var deskt = createDesktop(mainApp, 80, 30, 26)
let win1 = createWindow(20, 10, "ó")
win1.closeable = true
win1.resizable = true

let win2 = createWindow(40, 20, "Teszt2")

let radioGrp = createRadioGroupWithoutFrame()
let radioGrp2 = createRadioGroupWithFrame("Title")
radioGrp.addItem("Egy")
radioGrp.addItem("Kettő")
radioGrp.addItem("Három")
radioGrp2.addItem("Egy")
radioGrp2.addItem("Kettő")
radioGrp2.addItem("Három")

let rootNode = createTreeNode("Root")
discard rootNode.addNode("1")
discard rootNode.addNode("2")
let level1Node = createTreeNode("A")
discard level1Node.addNode("a")
discard level1Node.addNode("b")
let level2Node = createTreeNode("B")
discard level2Node.addNode("b")
discard level2Node.addNode("b")
let level3Node = createTreeNode("C")
discard level3Node.addNode("b")
discard level3Node.addNode("b")

level1Node.addNode(level2Node)
level1Node.addNode(level3Node)
rootNode.addNode(level1Node)

rootNode.opened = true
level1Node.opened = true
level2Node.opened = true
level3Node.opened = true
let tree1 = createStringTree(10, 10)
tree1.rootNode = rootNode

let checkBoxGrp = createCheckBoxGroupWithoutFrame()
let checkBoxGrp2 = createCheckBoxGroupWithFrame("Title")
checkBoxGrp.addItem("Egy")
checkBoxGrp.addItem("Kettő")
checkBoxGrp.addItem("Három")
checkBoxGrp2.addItem("Egy")
checkBoxGrp2.addItem("Kettő")
checkBoxGrp2.addItem("Három")



var sb = createStringSelectBox("Árvíztűrő furógép")
discard sb.addItem("1", cmdOk)
discard sb.addItem("Exit", cmdQuit)
let item = sb.addItem("2", cmdOk)
let item2 = item.addItem("3", cmdOk)
discard item.addItem("4", cmdOk)
discard item.addItem("5", cmdOk)
discard item.addItem("6", cmdOk)
discard item.addItem("7", cmdOk)
discard item2.addItem("8", cmdOk)
discard item2.addItem("9", cmdOk)

var cb = createComboBox(sb)


var btn1 = createButton("Hello", TCmd("Hello"))
var btn2 = createButton("Disabled", cmdOk, true)


let prgBar = createProgressBar(0, 100, 20, 1)
let prgBarWithCustomText = createProgressBar(0, 100, 20, 1)
prgBarWithCustomText.text = "Custom Text"
prgBarWithCustomText.value = 50

win2.resizable = true
let scroll = win2.AddScrollBarToRight()
scroll.setRange(0, 100)
win2.addView(prgBar, 6, 12)
win2.addView(prgBarWithCustomText, 6, 14)
win2.addView(btn1, 6, 16)
win2.addView(btn2, 16, 16)
win2.addView(radioGrp2, 1, 2)
win2.addView(radioGrp, 14, 2)

win2.addView(checkBoxGrp, 1, 8)
win2.addView(checkBoxGrp2, 14, 6)

deskt.addView(createTextField(10), 3, 1)

deskt.addView(win1, 7, 12)
deskt.addView(cb, 5, 6)
deskt.addView(win2, 30, 5)

win1.addView(tree1, 1, 1)


echo "222222222222222222222222222222222"
echo GC_getStatistics()
#let font = engine.loadFont(12)
#win.font = some(font)
#win2.font = some(font)

discard deskt.execute()