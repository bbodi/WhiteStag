import streams

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

import persister
import taskCell

var projectList: PList
var taskTree: PTree
var app: ref TAgility
var fileName: string = "agility.todo"  

proc currentProject(): PTask = 
  if projectList.selectedIndex.isNone:
    return nil
  return app.projects[projectList.selectedIndex.data]

proc currentTask(): PTask = 
  if taskTree.selectedIndex.isNone:
    return nil
  return cast[PTask](taskTree.selectedData)

proc addTaskToTreeNode(treeNode: PTreeNode, task: PTask) =
  if not task.completed or app.showFinishedTasks:
    let taskNode = treeNode.addNode(task)
    for childTask in task.childTasks:
      addTaskToTreeNode(taskNode, childTask)

proc fillTaskTree() =
  if taskTree.rootNode.isNone:
    taskTree.rootNode = createTreeNode("Root")
  taskTree.rootNode.data.opened = true
  taskTree.rootNode.data.children = @[]
  if currentProject() == nil:
    taskTree.changedStructure()
    return
  for task in currentProject().childTasks:
    addTaskToTreeNode(taskTree.rootNode.data, task)
  taskTree.changedStructure()

proc loadApp(filename: string): ref TAgility =
  let stream = newFileStream(filename, TFileMode.fmRead)
  if stream == nil:
    let ret = new(TAgility)
    ret.projects = @[]
    return ret
  var str = ""
  while stream.atEnd == false:
    str &= (stream.readLine & "\n")
  stream.close()
  return appFromString(str)

proc persistApplicationState(fileName: string) =
  let stream = newFileStream(fileName, TFileMode.fmWrite)
  let str = app.toString()
  stream.writeLn(str)
  stream.close()

proc fillProjectList() =
  projectList.clear()
  for project in app.projects:
    var allTasks = 0
    var completedTasks = 0
    for task in project.childTasks:
      allTasks += task.allChildTaskCount()
      completedTasks += task.completedChildTaskCount()
    projectList.addItem(project.name & " [" & $completedTasks & "/" & $allTasks & "]")

proc deleteTask(task: PTask) =
  for childTask in task.childTasks:
    deleteTask(childTask)
  let parentTask = task.parentTask
  if parentTask == nil:
    return
  let index = parentTask.childTasks.find(task)
  doAssert(index != -1, "removing a node: the node does not belong to his parent")
  parentTask.childTasks.delete(index)

method handleEvent*(self: ref TAgility, event: PEvent) =
  case event.kind:
  of TEventKind.eventCommand:
    case event.cmd:
    of cmdItemSelection:
      if event.sourceViewEquals(taskTree):
        let node = cast[PTreeNode](event.data)
        let task = cast[PTask](node.data)
        task.completed = not task.completed
        taskTree.changedStructure()
    of cmdQuit:
      persistApplicationState("agility.todo")
  of TEventKind.eventGetFocus:
    if event.sourceViewEquals(projectList):
      let prevSelectedProject = currentProject()
      projectList.selectedIndex.ifSome do (selectedIndex: int):
        fillTaskTree()          
  of TEventKind.eventKey:
    if event.pressedCtrl('p'):
      let name = deskt.showStringDialog("New Project")
      if name == nil:
        return
      app.projects.add((PProject(name: name, childTasks: @[])))
      fillProjectList()
    elif event.pressedShiftCtrl('i'):
      if currentProject() == nil:
        return
      if currentTask() == nil:
        return
      let taskName = deskt.showStringDialog("New SubTask")
      if taskName == nil:
        return
      let task = createTask(taskName)      
      task.parentTask = currentTask().parentTask
      currentTask().addChildTask(task)
      fillTaskTree()
      fillProjectList()
      event.setProcessed()
    elif event.pressedCtrl('h'):
      app.showFinishedTasks = not app.showFinishedTasks
      fillTaskTree()
    elif event.pressedCtrl('i'):
      if currentProject() == nil:
        return
      let taskName = deskt.showStringDialog("New Task")
      if taskName == nil:
        return
      let task = createTask(taskName)
      if currentTask() == nil:
        currentProject().childTasks.add(task)
      else:
        currentTask().parentTask.insertAfter( currentTask(), task)
      fillTaskTree()
      fillProjectList()
      event.setProcessed()
    elif event.key == TKey.KeyDelete:
      if currentTask() == nil:
        return
      let task = currentTask()
      deleteTask(task)
      if currentTask().parentTask == nil:
        let index = currentProject().childTasks.find(task)
        doAssert(index != -1, "removing a node: the node does not belong to his parent")
        currentProject().childTasks.delete(index)
      fillTaskTree()
    elif event.pressedCtrl('o'):
      event.setProcessed()
      let fname = deskt.showStringDialog("Open file")
      if fname == nil:
        return
      fileName = fname
      app = loadApp(fileName)
      fillProjectList()
      fillTaskTree()
      deskt.modified()
    elif event.pressedCtrl('s'):
      event.setProcessed()
      persistApplicationState(fileName)
  else:
    discard

proc createProjectTree() =
  projectList = createStringList(18, 28)

proc createProjectWindow(app: ref TAgility): PView =
  let win = createWindow(20, 30, "Projects")
  result = win
  win.closeable = false
  win.resizable = true
  win.growMode = {gmBottomToParentsBottom}
  createProjectTree()
  win.addView(projectList, 1,1)
  fillProjectList()

proc createTaskWindow(): PWindow =
  result = createWindow(110, 30, "Tasks")
  taskTree = createTaskTree(108, 28)
  taskTree.isRootHidden = true
  result.addView(taskTree, 1, 1)
  result.resizable = true


app = loadApp("agility.todo")
deskt = createDesktop(app, 130, 40, 16)
deskt.addView(createProjectWindow(app), 0, 0)
deskt.addView(createTaskWindow(), 20, 0)

echo GC_getStatistics()


discard deskt.execute()