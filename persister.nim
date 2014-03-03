import strutils
import unicode

import taskCell


proc toString(task: PTask, ident: int): string = 
  var prefix = repeatChar(ident)
  if task.completed: 
    prefix &= "✔ " 
  else: 
    prefix &= "☐ "
  if task.childTasks.len == 0:
    return prefix & task.name & "\n"
  else:
    result = prefix & task.name & "\n"
    for childTask in task.childTasks:
      result &= childTask.toString(ident+2)

proc hasChildTaskStrings(str: string, currentIdent: int): bool =
  let line = str.strip(true, false)
  let spaceCount = str.runeLen - line.runeLen
  return spaceCount > currentIdent

proc spaceCount(str: string): int =
  var i = 0
  while str.len > i and str[i] == ' ':
    inc i
  return i

proc taskFromString(task: PTask, line: string) = 
  var name: string
  let endLinePos = line.find("\n")
  if line.startsWith("✔ "):
    task.completed = true
    name = line[4..endLinePos-1]
  elif line.startsWith("☐ "):
    task.completed = false
    name = line[4..endLinePos-1]
  task.name = name

proc taskHierarchyFromStringR(parent: PTask, str: string, startIdent: int): string = 
  var line = str.strip(true, false)
  let task = createTask("")
  taskFromString(task, line)
  parent.addChildTask(task)
  let endLinePos = line.find("\n")
  if endLinePos == line.len-2:
    return ""
  var nextLine = line[endLinePos+2..high(line)]
  while nextLine != nil and nextLine.len > 0:
    if spaceCount(nextLine) > startIdent:
      nextLine = taskHierarchyFromStringR(task, nextLine, startIdent+2)
    elif spaceCount(nextLine) == startIdent:
      nextLine = taskHierarchyFromStringR(parent, nextLine, startIdent)
    else:
      return nextLine
  return nextLine


proc taskHierarchyFromString(task: PTask, str: string, startIdent: int): string = 
  var line: string = str.strip(true, false)
  taskFromString(task, line)
  let endLinePos = line.find("\n")
  var nextLine = line[endLinePos+2..high(line)]
  if spaceCount(nextLine) <= startIdent:
    return nextLine
  let fakk = taskHierarchyFromStringR(task, nextLine, startIdent+2)
  return fakk

proc toString(project: PProject): string = 
  result = project.name & ":\n"
  for task in project.childTasks:
    result &= task.toString(2)

proc toString*(app: ref TAgility): string = 
  result = ""
  for project in app.projects:
    result &= project.toString() & "\n"

proc projectFromString(project: PProject, str: string): string =
  var line: string = str.strip(true, false)
  let endLinePos = line.find("\n")
  project.name = line[0..endLinePos-2]
  project.childTasks = @[]
  var nextLine = line[endLinePos+2..high(line)]
  while (not nextLine.startsWith("\13\10")) and nextLine.len > 0:
    let task = createTask("")
    nextLine = taskHierarchyFromString(task, nextLine, 2)
    project.addChildTask(task)
  return nextLine

proc appFromString*(str: string): ref TAgility =
  result = TAgility.new()
  result.projects = @[]
  var line: string = str.strip(true, false)
  let endLinePos = line.find("\n")
  while line.len > 0 and line[0] != '\13':
    let project = PProject()
    line = projectFromString(project, line)
    result.projects.add(project)
    line = line[2..high(line)]

#let project = PProject()
#let app = appFromString("project1:\n  ☐ a\n    ☐ b\n  ☐ c\n\nproject2:\n  ☐ a\n    ☐ b\n      ☐ c\n\n")

when isMainModule:
  import unittest

  test "incompleted Task toString":
    let task = createTask("a")
    check "☐ a\n" == task.toString(0)

  test "completed Task toString":
    let task = createTask("a")
    task.completed = true
    check "✔ a\n" == task.toString(0)

  test "parent Task toString":
    let task = createTask("a")
    let task1 = createTask("b")
    let task2 = createTask("c")
    let task3 = createTask("d")
    task2.completed = true
    task.addChildTask(task1)
    task1.addChildTask(task2)
    task.addChildTask(task3)
    check "☐ a\n  ✔ b\n    ✔ c\n  ☐ d\n" == task.toString(0)

  test "incompleted Task toString with ident":
    let task = createTask("a")
    check "  ☐ a\n" == task.toString(2)

  test "completed Task toString with ident":
    let task = createTask("a")
    task.completed = true
    check "  ✔ a\n" == task.toString(2)

  test "parent Task toString with ident":
    let task = createTask("a")
    let task1 = createTask("b")
    let task2 = createTask("c")
    let task3 = createTask("d")
    task2.completed = true
    task.addChildTask(task1)
    task1.addChildTask(task2)
    task.addChildTask(task3)
    check "  ☐ a\n    ✔ b\n      ✔ c\n    ☐ d\n" == task.toString(2)

  test "incompleted Task fromString":
    let task = createTask("")
    taskFromString(task, "☐ a\n")
    check task.name == "a"
    check task.completed == false

  test "completed Task fromString":
    let task = createTask("")
    taskFromString(task, "✔ a\n")
    check task.name == "a"
    check task.completed == true

  test "taskFromString reads only one task":
    let task = createTask("")
    taskFromString(task, "✔ a\n☐ b\n")
    check task.name == "a"
    check task.completed == true

  test "parent Task taskHierarchyFromString":
    let task = createTask("")
    let str = taskHierarchyFromString(task, "☐ a\n  ✔ b\n    ✔ c\n  ☐ d\n", 0)
    check task.name == "a"
    check task.childTasks.len == 2
    check task.completed == false
    check task.parentTask == nil

    check task.childTasks[0].parentTask == task
    check task.childTasks[0].name == "b"
    check task.childTasks[0].completed == true
    check task.childTasks[0].childTasks.len == 1
    check task.childTasks[0].childTasks[0].parentTask == task.childTasks[0]
    check task.childTasks[0].childTasks[0].name == "c"
    check task.childTasks[0].childTasks[0].completed == true
    check task.childTasks[0].childTasks[0].childTasks.len == 0

    check task.childTasks[1].name == "d"
    check task.childTasks[1].completed == false
    check task.childTasks[1].childTasks.len == 0

    check str == ""

  test "project toString":
    let project = PProject(name: "project", childTasks: @[])
    project.childTasks.add(createTask("a"))
    project.childTasks.add(createTask("c"))
    project.childTasks[0].addChildTask(createTask("b"))
    check "project:\n  ☐ a\n    ☐ b\n  ☐ c\n" == project.toString()

  test "project fromString":
    let project = PProject()
    let str = projectFromString(project, "project:\n  ☐ a\n    ☐ b\n  ☐ c\n")
    check project.name == "project"
    check project.childTasks.len == 2
    check project.childTasks[0].parentTask == project
    check project.childTasks[0].name == "a"
    check project.childTasks[0].childTasks.len == 1

    check project.childTasks[0].childTasks[0].name == "b"
    check project.childTasks[0].childTasks[0].childTasks.len == 0

    check project.childTasks[1].parentTask == project
    check project.childTasks[1].name == "c"
    check project.childTasks[1].childTasks.len == 0
    check str == ""

  test "App fromString":
    let app = appFromString("project1:\n  ☐ a\n    ☐ b\n  ☐ c\n\nproject2:\n  ☐ a\n    ☐ b\n      ☐ c\n\n")
    let p1 = app.projects[0]
    check app.projects.len == 2
    check p1.name == "project1"
    check p1.childTasks.len == 2
    check p1.childTasks[0].parentTask == p1
    check p1.childTasks[0].name == "a"
    check p1.childTasks[0].childTasks.len == 1

    check p1.childTasks[0].childTasks[0].name == "b"
    check p1.childTasks[0].childTasks[0].childTasks.len == 0

    check p1.childTasks[1].parentTask == p1
    check p1.childTasks[1].name == "c"
    check p1.childTasks[1].childTasks.len == 0

    let p2 = app.projects[1]
    check p2.name == "project2"
    check p2.childTasks.len == 1
    check p2.childTasks[0].parentTask == p2
    check p2.childTasks[0].name == "a"
    check p2.childTasks[0].childTasks.len == 1
    check p2.childTasks[0].childTasks[0].name == "b"
    check p2.childTasks[0].childTasks[0].childTasks.len == 1
    check p2.childTasks[0].childTasks[0].childTasks[0].name == "c"
    check p2.childTasks[0].childTasks[0].childTasks[0].childTasks.len == 0

  test "App toString":
    let app = new(TAgility)
    app.projects = @[]
    let project1 = PProject(name: "project1", childTasks: @[])
    project1.childTasks.add(createTask("a"))
    project1.childTasks.add(createTask("c"))
    project1.childTasks[0].addChildTask(createTask("b"))

    let project2 = PProject(name: "project2", childTasks: @[])
    project2.childTasks.add(createTask("a"))
    project2.childTasks[0].addChildTask(createTask("b"))
    project2.childTasks[0].childTasks[0].addChildTask(createTask("c"))

    app.projects.add(project1)
    app.projects.add(project2)

    let expected = "project1:\n  ☐ a\n    ☐ b\n  ☐ c\n\nproject2:\n  ☐ a\n    ☐ b\n      ☐ c\n\n"
    check expected == app.toString()

  test "test read project 2":
    let str = """fakk1:
  ☐ task1
  ☐ task2

fakk2:
  ☐ task3
  ☐ task4
    ☐ task5


"""
    let app = appFromString(str)
    check app.projects.len == 2
    let p1 = app.projects[0]
    check p1.name == "fakk1"
    check p1.childTasks.len == 2
    check p1.childTasks[0].name == "task1"
    check p1.childTasks[0].childTasks.len == 0
    check p1.childTasks[1].name == "task2"
    check p1.childTasks[1].childTasks.len == 0

    let p2 = app.projects[1]
    check p2.name == "fakk2"
    check p2.childTasks.len == 2
    check p2.childTasks[0].name == "task3"
    check p2.childTasks[0].childTasks.len == 0
    check p2.childTasks[1].name == "task4"
    check p2.childTasks[1].childTasks.len == 1
    check p2.childTasks[1].childTasks[0].name == "task5"
    check p2.childTasks[1].childTasks[0].childTasks.len == 0