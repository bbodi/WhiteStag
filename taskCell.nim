import unicode

import WhiteStagEditor/view
import WhiteStagEditor/drawbuffer
import WhiteStagEditor/event
import WhiteStagEditor/tree
import WhiteStagEditor/progressbar
import WhiteStagEditor/color
import WhiteStagEditor/desktop
import WhiteStagEditor/rect
import WhiteStagEditor/selectbox

type
  PProject* = ref TTask
  PTask* = ref TTask
  TTask* = object
    name*: string
    childTasks*: seq[PTask]
    pCompleted: bool
    parentTask*: PTask

  TAgility* = object of TApplication
    projects*: seq[PProject]
    showFinishedTasks*: bool

  PTaskCellView* = ref TTaskCellView
  TTaskCellView* = object of TTreeCellView
    progrBar: PProgressBar
    task: PTask

  

  PTaskTreeCellViewFactory = ref TTaskTreeCellViewFactory
  TTaskTreeCellViewFactory = object of TTreeCellViewFactory

proc completed*(self: PTask): bool

var deskt*: PDesktop
var actionMenu = createStringSelectBox("Action", false)
discard actionMenu.addItem("Rename", cmdOk)
discard actionMenu.addItem("Delete", cmdOk)


proc addChildTask*(self: PTask, task: PTask) =
  self.childTasks.add(task)
  task.parentTask = self

proc insertAfter*(self: PTask, afterThat: PTask, task: PTask) =
  var insertAfterIndex = -1
  for i, child in self.childTasks:
    if child == afterThat:
      insertAfterIndex = i
      break
  if insertAfterIndex == -1:
    return
  self.childTasks.insert(task, insertAfterIndex+1)
  task.parentTask = self

proc createTask*(name: string): PTask = PTask(name: name, childTasks: @[])

method createCellView*(self: PTaskTreeCellViewFactory, w, h: int): PTreeCellView = 
  let cell = new(TTaskCellView)
  cell.setWidthHeight(w, 1)
  return cell

proc allChildTaskCount*(self: PTask): int = 
  if self.childTasks.len == 0:
    return 1
  var tasks = 0
  for childTask in self.childTasks:
    tasks += allChildTaskCount(childTask)
  return tasks

proc completedChildTaskCount*(self: PTask): int = 
  if self.childTasks.len == 0:
    return if self.completed: 1 else: 0
  var tasks = 0
  for childTask in self.childTasks:
    tasks += completedChildTaskCount(childTask)
  return tasks

proc `completed=`*(self: PTask, comp: bool) =
  self.pCompleted = comp

proc completed*(self: PTask): bool =
  if self.childTasks.len == 0: 
    return self.pCompleted
  return self.allChildTaskCount == self.completedChildTaskCount

proc taskToStrFunc*(task: PTask): string = 
  var prefix = "  "
  if task.childTasks.len == 0:
    prefix = if task.completed: "✔ " else: "☐ "
  result = prefix & task.name

method stringify*(self: PTaskTreeCellViewFactory, data: pointer): string =  taskToStrFunc(cast[PTask](data))

method setNode*(self: PTaskCellView, node: PTreeNode) = 
  self.clearViews()
  self.node = node
  self.task = cast[PTask](node.data)
  let task = self.task
  if task.childTasks.len > 0:
    let progrBarWidth = self.node.tree.w - self.ident*2
    self.progrBar = createProgressBar(0, 100, progrBarWidth, 1)
    self.addView(self.progrBar, self.ident*2, 0)
    let all = allChildTaskCount(task)
    let completed = completedChildTaskCount(task)
    self.progrBar.text = self.task.name
    self.progrBar.value = int(completed / all * 100)
    
method name(self: PTaskCellView): string = "TaskCellView"

method handleEvent(self: PTaskCellView, event: PEvent) = 
  case event.kind:
  of TEventKind.eventMouseButtonDown:    
    if event.local and event.mouseButton == TMouseButton.mbtnRight:
      let commandString = cast[string](self.executeView(actionMenu, event.localMouseX, 1).data)
      if commandString == "Rename":
        let name = deskt.showStringDialog("Rename", self.task.name)
        if name == nil:
          return
        self.task.name = name
      event.setProcessed()
  else:
    discard

proc drawTreeItem*(self: PTreeCellView, data: string, buff: var TDrawBuffer) =
  buff.clearCells(0, 0, self.w, self.h)
  let bgColor = 
    if self.node.tree.isSelected(self):
      SelectedItemBgColor.color(self.isFocused)
    else:
      PanelColor.color(self.isFocused)
  buff.setCells(0, 0, self.w, self.h, bg = bgColor )
  let prefix = if self.node.opened: "-" elif self.node.children.len == 0: " " else: "+"
  let textColor = PanelTextColor.color(self.isFocused)
  buff.writeText(self.ident, 0, prefix & " " & data, fg = textColor)

method draw(self: PTaskCellView): TDrawBuffer = 
  let str = taskToStrFunc(self.task)
  self.drawTreeItem(str, self.buff)
  result = self.buff

proc createTaskTree*(w, h: int): PTree = 
  createTree(PTaskTreeCellViewFactory(), w, h)
