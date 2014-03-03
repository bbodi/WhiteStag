import unicode

import view
import frame
import color
import drawbuffer
import event
import option
import sdlengine
import rect


type
  PTreeNode* = ref TTreeNode
  TTreeNode* = object
    data*: pointer
    parentNode*: PTreeNode
    children*: seq[PTreeNode]
    opened*: bool
    tree*: PTree

  PTreeCellView* = ref TTreeCellView
  TTreeCellView* = object of TCellView
    ident*: int
    node*: PTreeNode

  PTreeCellViewFactory* = ref TTreeCellViewFactory
  TTreeCellViewFactory* = object of TCellViewFactory

  PTree* = ref TTree
  TTree* = object of TView
    pSelectedIndex: TOption[int]
    pRootNode*: TOption[PTreeNode]
    cellViewFactory*: PTreeCellViewFactory
    cellViews: seq[PTreeCellView]
    pRowCount: int
    skippedNodes: int
    startIndex: int
    pIsRootHidden: bool
    allNodesAreDrawn: bool

method createCellView*(self: PTreeCellViewFactory, w, h: int): PTreeCellView = quit "to override PTreeCellViewFactory.createCellView!"

method setNode*(self: PTreeCellView, node: PTreeNode) = quit "setNodeto override!"

proc `selectedIndex`*(self: PTree): TOption[int] =
  return self.pSelectedIndex

proc `rowCount`*(self: PTree): int =
  return self.pRowCount

proc assignCellViewsToNodes(self: PTree, node: PTreeNode, cellViewIndex, ident: int): int = 
  node.tree = self
  if cellViewIndex >= self.h:
    return -1
  var nextIndex = cellViewIndex
  let isRootNode = self.pRootNode.equals(node)
  
  if not isRootNode or not self.pIsRootHidden:
    if self.skippedNodes >= self.startIndex:
      let cellView = self.cellViews[cellViewIndex]
      cellView.ident = ident
      cellView.setWidthHeight(self.w, 1)
      cellView.setNode(node)
      self.addView(cellView, 0, cellViewIndex)
      inc self.pRowCount
      inc nextIndex
    else:
      inc self.skippedNodes
  let thisIsTheRootAndItIsHidden = isRootNode and self.pIsRootHidden
  if not node.opened and (not thisIsTheRootAndItIsHidden):
    return nextIndex
  for i, child in node.children:
    nextIndex = self.assignCellViewsToNodes(child, nextIndex, ident+1)
    if nextIndex < 0:
      return nextIndex
  return nextIndex

proc changedStructure*(self: PTree) = 
  self.views = @[]
  self.pRowCount = 0
  self.skippedNodes = 0
  if self.pRootNode.isNone:
    return
  let lastIndex = self.assignCellViewsToNodes(self.pRootNode.data, 0, 0)
  self.allNodesAreDrawn = lastIndex != -1
  if self.pRowCount == 0:
    echo("if self.pRowCount == 0:")
    self.pSelectedIndex = none[int]()
  else:
    echo("qweqweqweqwe qwe q qw")
    self.pSelectedIndex.withData do (selectedIndex: var int):
      if selectedIndex >= self.pRowCount:
        selectedIndex = self.pRowCount-1
  self.modified()

proc `isRootHidden`*(self: PTree): bool =
  return self.pIsRootHidden

proc `isRootHidden=`*(self: PTree, hidden: bool) =
  if hidden != self.pIsRootHidden:
    self.pIsRootHidden = hidden

proc `rootNode`*(self: PTree): TOption[PTreeNode] =
  return self.pRootNode

proc `rootNode=`*(self: PTree, maybeNode: TOption[PTreeNode]) =
  self.pRootNode = maybeNode

proc `rootNode=`*(self: PTree, node: PTreeNode) =
  self.rootNode = some[PTreeNode](node)

proc handleMouse(self: PTree, event: PEvent) =
  discard

proc open*(self: PTreeNode) = 
  self.opened = true

proc doClose*(self: PTreeNode) = 
  self.opened = false
  for childNode in self.children:
    childNode.doClose()

proc close*(self: PTreeNode) = 
  self.doClose()

proc handleKey*(self: PTree, event: PEvent) =
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
      let overflowed = selectedIndex == self.pRowCount-1
      if not overflowed or not self.allNodesAreDrawn:
        if overflowed:
          inc self.startIndex
          self.changedStructure()
        else:
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
      elif self.skippedNodes > 0:
        dec self.startIndex
        self.changedStructure()
  of TKey.KeyEnter:
    event.setProcessed()
    if self.pSelectedIndex.isNone:
      return
    let index = self.pSelectedIndex.data()
    let cell = self.cellViews[index]
    let node = cell.node
    if node.children.len > 0:
      if node.opened:
        node.close()
      else:
        node.open()
      self.changedStructure()
      self.modified()
    else:
      self.broadcastCommand(cmdItemSelection, node)
  else:
    discard
    
method name(self: PTree): string = "Tree"

proc setSelectedIndexToTheFocusedChild(self: PTree, event: PEvent) = 
  var index = 0
  for cellView in self.cellViews:
    if event.sourceViewEquals(cellView):
      break
    inc index
  if index < self.h:
    self.pSelectedIndex = some[int](index)

method handleEvent(self: PTree, event: PEvent) = 
  case event.kind:
  of TEventKind.eventMouseButtonDown:
    if event.local:
      event.setProcessed()
  of TEventKind.eventKey:
    self.handleKey(event)
  of TEventKind.eventGetFocus, TEventKind.eventBecomeCurrentView:
    let treeWasSelected = event.kind == TEventKind.eventBecomeCurrentView and event.sourceViewEquals(self)
    if treeWasSelected:
      self.pSelectedIndex.ifSome do (selectedIndex: int):
        setCurrentView(self.cellViews[selectedIndex])
      return
    self.setSelectedIndexToTheFocusedChild(event)
  else:
    discard

proc isSelected*(self: PTree, cellView: PTreeCellView): bool =
  if self.pSelectedIndex.isNone:
    return false
  return self.cellViews[self.pSelectedIndex.data()] == cellView

proc selectedNode*(self: PTree): PTreeNode =
  if self.pSelectedIndex.isNone:
    return nil
  result = self.cellViews[self.pSelectedIndex.data()].node

proc selectedData*(self: PTree): pointer =
  if self.pSelectedIndex.isNone:
    return nil
  let data = self.cellViews[self.pSelectedIndex.data()].node.data
  result = (data)

proc getDataAt*(self: PTree, index: int): pointer =
  let data = self.cellViews[index].node.data
  result = (data)

method draw(self: PTree): TDrawBuffer = 
  self.buff.setCells(0, 0, self.w, self.w, bg = PanelColor.color(self.isFocused))
  return self.buff

proc remove*(self: PTreeNode) =
  echo repr(self)
  if self.parentNode != nil:
    let index = self.parentNode.children.find(self)
    doAssert(index != -1, "removing a node: the node does not belong to his parent")
    self.parentNode.children.delete(index)
  elif self.tree != nil:
    self.tree.rootNode = none[PTreeNode]()

proc fillCellViews(self: PTree) =
  if self.cellViews.len < self.h:
    for i in 0..self.h-1:
      let cellView = self.cellViewFactory.createCellView(self.w, self.h)
      cellView.growMode = {gmRightToParentsRight}
      self.cellViews.add(cellView)

method onChangeSize*(self: PTree, deltaW, deltaH: int) =
  self.groupOnChangeSize(deltaW, deltaH)
  if deltaH != 0:
    self.fillCellViews()
    self.changedStructure()

proc createTree*(cellViewFactory: PTreeCellViewFactory, w, h: int): PTree = 
  result = new(TTree)
  result.cellViews = @[]
  result.rootNode = none[PTreeNode]()
  result.cellViewFactory = cellViewFactory
  result.growMode = gmGrowAsParent
  result.setWidthHeight(w, h)

proc createTreeNode*[T](data: T): PTreeNode = 
  result = new(TTreeNode)
  result.children = @[]
  result.setData(data)

proc addNode*(self: PTreeNode, child: PTreeNode) = 
  self.children.add(child)

proc addNode*[t](self: PTreeNode, data: T): PTreeNode = 
  result = createTreeNode(data)
  self.addNode(result)

proc setData*[T](self: PTreeNode, data: T) = 
  self.data = cast[pointer](data)


proc hasChild*(self: PTreeNode): bool = self.children.len > 0

when isMainModule:
  import unittest
  import font
  import pixel

  type
    PTestTreeCellViewFactory = ref TTestTreeCellViewFactory
    TTestTreeCellViewFactory = object of TTreeCellViewFactory

    PTestTreeCellView = ref TTestTreeCellView
    TTestTreeCellView = object of TTreeCellView
      identAtSetup: int

  method setNode*(self: PTestTreeCellView, node: PTreeNode) = 
    self.views = @[]
    self.node = node
    self.identAtSetup = self.ident

  method name(self: PTestTreeCellView): string = "TestCellView"
  method handleEvent(self: PTestTreeCellView, event: PEvent) = discard
  method draw(self: PTestTreeCellView): TDrawBuffer = self.buff

  method createCellView(self: PTestTreeCellViewFactory, w, h: int): PTreeCellView = 
    let cell = new(TTestTreeCellView)
    cell.setWidthHeight(w, 1)
    return cell

  method stringify(self: PTestTreeCellViewFactory, data: pointer): string = 
    "test"

  proc createTestTree(): PTree = 
    createTree(PTestTreeCellViewFactory(), 10, 10)
    

  suite "Tree Test Suite":
    setup:
      var root = createTreeNode("root")
      var a = root.addNode("a")
      var b = root.addNode("b")
      var c = root.addNode("c")
      var tree = createTestTree()
      tree.rootNode = root
      tree.font = some(TFont(charWidth: TPixel(1), charHeight: TPixel(1)))
      tree.changedStructure()

    test "closing closes recursively":
      discard a.addNode("a child")
      root.open()
      a.open()
      tree.changedStructure()
      var event = PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowDown)
      tree.broadcast(event)
      check tree.selectedIndex.data == 0

      event = PEvent(kind: TEventKind.eventKey, key: TKey.KeyEnter)
      tree.broadcast(event)
      check root.opened == false
      check a.opened == false

    test "identation should be reseted on each structural rebuild":
      discard b.addNode("b child")
      root.open()
      tree.changedStructure()
      let cellView: PTestTreeCellView = cast[PTestTreeCellView](tree.cellViews[3])
      check cast[string](cellView.node.data) == "c"
      check cellView.identAtSetup == 1
      b.open()
      tree.changedStructure()
      check cast[string](cellView.node.data) == "b child"
      check cellView.identAtSetup == 2
      b.close()
      tree.changedStructure()
      check cast[string](cellView.node.data) == "c"
      check cellView.identAtSetup == 1

    test "root is visible by default":
      check tree.isRootHidden == false
      check tree.rowCount == 1

    test "open":
      check tree.isRootHidden == false
      root.open()
      tree.changedStructure()
      check tree.rowCount == 4

    test "If root is NOT visible, its children are drawn independently from its opened status":
      root.close()
      tree.isRootHidden = true
      tree.changedStructure()
      check tree.rowCount == 3

    test "tree with null root":
      tree.rootNode = none[PTreeNode]()
      tree.changedStructure()
      check tree.rowCount == 0

    test "Opening a node that is attached to a tree updates the tree":
      check root.opened == false
      root.open()
      tree.changedStructure()
      check root.opened == true

    test "Down key should select the first item if no item is selected when pressed":
      tree.isRootHidden = true
      root.open()
      tree.changedStructure()
      let event = PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowDown)
      tree.broadcast(event)
      check tree.selectedIndex.data == 0
      check tree.dirty

    test "Up key should select the first item if no item is selected when pressed":
      tree.isRootHidden = true
      root.open()
      tree.changedStructure()
      let event = PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowUp)
      tree.broadcast(event)
      check tree.selectedIndex.data == 2
      check tree.dirty

    test "close closes recursively":
      root.open()
      a.open()
      tree.changedStructure()
      check a.opened == true
      root.close()
      tree.changedStructure()
      check root.opened == false
      check a.opened == false

    test "Resizing the tree removes the elements that are out of view":
      root.open()
      tree.changedStructure()
      check tree.rowCount == 4
      tree.setWidthHeight(10, 2)
      check tree.rowCount == 2
      tree.setWidthHeight(10, 0)
      check tree.rowCount == 0

    test "Scrolling down and up":
      root.open()
      tree.changedStructure()
      check tree.rowCount == 4
      tree.setWidthHeight(10, 2)
      check tree.rowCount == 2
      var event = PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowDown)
      tree.broadcast(event)
      check tree.selectedIndex.data == 0
      check ((cast[string](tree.getDataAt(0))) == "root")
      event = PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowDown)
      tree.broadcast(event)
      check tree.selectedIndex.data == 1
      check ((cast[string](tree.getDataAt(0))) == "root")
      check ((cast[string](tree.getDataAt(1))) == "a")
      event = PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowDown)
      tree.broadcast(event)
      check tree.selectedIndex.data == 1
      check ((cast[string](tree.getDataAt(0))) == "a")
      check ((cast[string](tree.getDataAt(1))) == "b")
      event = PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowDown)
      tree.broadcast(event)
      check tree.selectedIndex.data == 1
      check ((cast[string](tree.getDataAt(0))) == "b")
      check ((cast[string](tree.getDataAt(1))) == "c")
      check tree.rowCount == 2

      event = PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowUp)
      tree.broadcast(event)
      check tree.selectedIndex.data == 0
      check ((cast[string](tree.getDataAt(0))) == "b")
      check ((cast[string](tree.getDataAt(1))) == "c")
      check tree.rowCount == 2


      event = PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowUp)
      tree.broadcast(event)
      check tree.selectedIndex.data == 0
      check ((cast[string](tree.getDataAt(0))) == "a")
      check ((cast[string](tree.getDataAt(1))) == "b")
      check tree.rowCount == 2

    test "Scrolling down when the elements occupy smaller space then the whole tree":
      root.open()
      tree.changedStructure()
      check tree.rowCount == 4
      check ((cast[string](tree.getDataAt(0))) == "root")
      check ((cast[string](tree.getDataAt(1))) == "a")
      check ((cast[string](tree.getDataAt(2))) == "b")
      check ((cast[string](tree.getDataAt(3))) == "c")

      var event = PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowDown)
      tree.broadcast(event)
      check tree.selectedIndex.data == 0
      event = PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowDown)
      tree.broadcast(event)
      check tree.selectedIndex.data == 1
      event = PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowDown)
      tree.broadcast(event)
      check tree.selectedIndex.data == 2
      event = PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowDown)
      tree.broadcast(event)
      check tree.selectedIndex.data == 3
      event = PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowDown)
      tree.broadcast(event)
      check tree.selectedIndex.data == 3

    test "Scrolling up when the elements occupy smaller space then the whole tree":
      root.open()
      tree.changedStructure()
      check tree.rowCount == 4
      check ((cast[string](tree.getDataAt(0))) == "root")
      check ((cast[string](tree.getDataAt(1))) == "a")
      check ((cast[string](tree.getDataAt(2))) == "b")
      check ((cast[string](tree.getDataAt(3))) == "c")

      var event = PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowDown)
      tree.broadcast(event)
      check tree.selectedIndex.data == 0
      event = PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowUp)
      tree.broadcast(event)
      check tree.selectedIndex.data == 0

    test "Rebuilding the tree invalidates the selectedIndex":
      root.open()
      tree.changedStructure()
      check tree.rowCount == 4
      check ((cast[string](tree.getDataAt(0))) == "root")
      check ((cast[string](tree.getDataAt(1))) == "a")
      check ((cast[string](tree.getDataAt(2))) == "b")
      check ((cast[string](tree.getDataAt(3))) == "c")
      var event = PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowDown)
      tree.broadcast(event)
      check tree.selectedIndex.data == 0
      event = PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowDown)
      tree.broadcast(event)
      check tree.selectedIndex.data == 1
      event = PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowDown)
      tree.broadcast(event)
      check tree.selectedIndex.data == 2
      event = PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowDown)
      tree.broadcast(event)
      check tree.selectedIndex.data == 3
      root.close()
      tree.changedStructure()
      check tree.rowCount == 1
      check tree.selectedIndex.data == 0