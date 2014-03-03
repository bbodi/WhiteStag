import unicode

import view
import frame
import color
import drawbuffer
import event
import option
import rect


type
  PListNode* = ref TListNode
  TListNode* = object
    data*: pointer
    list*: PList

  PListCellView* = ref TListCellView
  TListCellView* = object of TCellView

  TListCellViewFactoryMethod* = proc(w, h: int): PListCellView

  PList* = ref TList
  TList* = object of TView
    pSelectedIndex: TOption[int]
    nodes: seq[PListNode]
    cellViewFactory: TListCellViewFactoryMethod
    cellViews: seq[PListCellView]
    rowCount: int

method setNode*(self: PListCellView, node: PListNode) = quit "PListCellView.setNode to override!"

proc `selectedIndex`*(self: PList): TOption[int] = self.pSelectedIndex

proc changedStructure*(self: PList) = 
  self.views = @[]
  self.rowCount = 0
  for cellViewIndex, node in self.nodes:
    node.list = self
    let cellView = self.cellViews[cellViewIndex]
    cellView.setNode(node)
    inc self.rowCount
    self.addView(cellView, 0, cellViewIndex)
    

proc handleMouse(self: PList, event: PEvent) =
  discard

proc handleKey*(self: PList, event: PEvent) =
  case event.key:
  of TKey.KeyArrowDown:
    event.setProcessed()
    if self.pSelectedIndex.isNone:
      if self.rowCount > 0:
        self.pSelectedIndex = some(0)
        setCurrentView(self.cellViews[0])
        self.modified()
      return
    self.pSelectedIndex.withData do (selectedIndex: var int):
      if selectedIndex < self.rowCount - 1:
        inc selectedIndex
        self.modified()
        setCurrentView(self.cellViews[selectedIndex])
  of TKey.KeyArrowUp:
    event.setProcessed()
    if self.pSelectedIndex.isNone:
      if self.rowCount > 0:
        self.pSelectedIndex = some(self.rowCount-1)
        setCurrentView(self.cellViews[self.rowCount-1])
        self.modified()
      return
    self.pSelectedIndex.withData do (selectedIndex: var int):
      if selectedIndex > 0:
        dec selectedIndex
        self.modified()
        setCurrentView(self.cellViews[selectedIndex])
  of TKey.KeyEnter:
    event.setProcessed()
  else:
    discard

proc isSelected(self: PList, cellView: PListCellView): bool =
  result = 
    if self.pSelectedIndex.isSome():
      self.cellViews[self.pSelectedIndex.data()] == cellView
    else: 
      false
    
method name(self: PList): string = "List"

proc setSelectedIndexToTheFocusedChild(self: PList, event: PEvent) = 
  var index = 0
  for cellView in self.cellViews:
    if event.sourceViewEquals(cellView):
      break
    inc index
  if index < self.rowCount:
    self.pSelectedIndex = some(index)

method handleEvent(self: PList, event: PEvent) = 
  case event.kind:
  of TEventKind.eventMouseButtonDown:
    if event.local:
      event.setProcessed()
  of TEventKind.eventKey:
    self.handleKey(event)
  of TEventKind.eventBecomeCurrentView:
    let listWasSelected = event.sourceViewEquals(self)
    if listWasSelected:
      self.pSelectedIndex.ifSome do (selectedIndex: int):
        setCurrentView(self.cellViews[selectedIndex])
    else:
      self.setSelectedIndexToTheFocusedChild(event)
  else:
    discard

method draw(self: PList): TDrawBuffer = 
  self.buff.setCells(0, 0, self.w, self.w, bg = PanelColor.color(self.isFocused))
  return self.buff

proc createList*(cellViewFactoy: TListCellViewFactoryMethod, w, h: int,): PList = 
  result = new(TList)
  result.setWidthHeight(w, h)
  result.nodes = @[]
  result.cellViews = @[]
  for i in 0..h-1:
    let cellView = cellViewFactoy(w, h)
    result.cellViews.add(cellView)
  result.changedStructure()

proc createNode*[T](data: T): PListNode = 
  result = new(TListNode)
  result.setData(data)

proc clear*(self: PList) =
  self.nodes = @[]
  self.changedStructure()

proc addNode*(self: PList, child: PListNode) = 
  self.nodes.add(child)
  self.changedStructure()

proc addItem*[t](self: PList, data: T) = 
  self.addNode(createNode(data))

proc setData*[T](self: PListNode, data: T) = 
  self.data = cast[pointer](data)

type
  
  PStringCellView = ref TStringCellView
  TStringCellView = object of TListCellView
    data: string
    node: PListNode

method setNode*(self: PStringCellView, node: PListNode) = 
  self.views = @[]
  self.node = node
  self.data = cast[string](node.data)

method name(self: PStringCellView): string = "List-StringCellView"

method handleEvent(self: PStringCellView, event: PEvent) = 
  case event.kind:
  of TEventKind.eventMouseButtonDown:
    discard
  else:
    discard

method draw(self: PStringCellView): TDrawBuffer = 
  let bgColor = 
    if self.node.list.isSelected(self):
      SelectedItemBgColor.color(self.isFocused)
    else:
      PanelColor.color(self.isFocused)
  self.buff.setCells(0, 0, self.w, 1, bg = bgColor)

  let textColor = PanelTextColor.color(self.isFocused)
  self.buff.writeText(0, 0, self.data, fg = textColor)
  return self.buff

proc createStringCellView(w, h: int): PStringCellView {.procvar.} = 
  result = new(TStringCellView)
  result.setWidthHeight(w, 1)

proc createStringList*(w, h: int): PList = createList(createStringCellView, w, h)

when isMainModule:
  import unittest
  import font
  import pixel
  
  suite "List Test Suite":
    setup:
      var list = createStringList(10, 10)
      list.addItem("a")
      list.addItem("b")
      list.addItem("c")
      list.font = some(TFont(charWidth: TPixel(1), charHeight: TPixel(1)))
  
    test "inheritance":
      discard
      let view: PView = list
      check "List" == view.name
      discard view.draw()

    test "clicking on Items sets the selectedIndex of the List":
      list.broadcast(PEvent(kind: TEventKind.eventMouseButtonDown, mouseX: TPixel(1), mouseY: TPixel(1)))
      echo "1"
      check list.selectedIndex.isSome
      check list.selectedIndex.data == 1
      list.broadcast(PEvent(kind: TEventKind.eventMouseButtonDown, mouseX: TPixel(1), mouseY: TPixel(0)))
      echo "2"
      check list.selectedIndex.isSome
      check list.selectedIndex.data == 0
      list.broadcast(PEvent(kind: TEventKind.eventMouseButtonDown, mouseX: TPixel(1), mouseY: TPixel(1)))
      echo "3"
      check list.selectedIndex.isSome
      check list.selectedIndex.data == 1
      list.broadcast(PEvent(kind: TEventKind.eventMouseButtonDown, mouseX: TPixel(1), mouseY: TPixel(2)))
      echo "4"
      check list.selectedIndex.isSome
      check list.selectedIndex.data == 2

    test "handleEvent catches cursor events regardless of cursor position":
      let eventKeyDown = PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowDown)
      list.broadcast(eventKeyDown)
      check (eventKeyDown.kind == TEventKind.eventNothing)

      let eventKeyUp = PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowUp)
      list.broadcast(eventKeyUp)
      check (eventKeyUp.kind == TEventKind.eventNothing)

    test "Down key should select the first item if no item is selected when pressed":
      let event = PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowDown)
      list.broadcast(event)
      check list.selectedIndex.equals(0)
      check list.dirty

    test "Up key should select the first item if no item is selected when pressed":
      let event = PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowUp)
      list.broadcast(event)
      check list.selectedIndex.equals(2)
      check list.dirty