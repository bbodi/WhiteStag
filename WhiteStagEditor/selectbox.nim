import unicode

import view
import frame
import color
import drawbuffer
import event
import option
import sdlengine
import rect
import utfstring

# Egyelőre csak UTFStringgel működik. Amint jó lesz a generikus, akkor átírni!

type
  PSelectItem* = ref TSelectItem
  TSelectItem* = object
    data: ref TObject
    cmd: TCmd
    childBox: PSelectBox
    rootBox: PSelectBox

  TSelectBoxItemDrawerFunc* = proc(self: PSelectBox, data: ref TObject, index: int, selected: bool, buff: var TDrawBuffer)
  TSelectBoxItemWidthFunc* = proc(self: PSelectBox, data: ref TObject): int
  # TODO: ha működik majd a method -s típussal, akkor írd vissza
  PSelectBox* = ref TSelectBox
  TSelectBox* = object of TView
    frame: TWindowFrame
    selectedIndex*: int # TODO: readonly!
    items: seq[PSelectItem]
    selectBoxItemWidthFunc*: TSelectBoxItemWidthFunc
    selectBoxItemDrawerFunc*: TSelectBoxItemDrawerFunc


proc getClickedItemIndex(self: PSelectBox, mouseY: int): int = 
  let firstItemIndex = if self.frame.hasBorder: 1 else: 0
  return mouseY - firstItemIndex

proc handleMouse(self: PSelectBox, event: PEvent) =
  discard

proc handleItemSelection*(self: PSelectBox, selectedIndex: int) =
  let selectedItem = self.items[selectedIndex]
  if selectedItem.childBox == nil:
    if self.isExecuting:
      self.stopExecutingWith(selectedItem.cmd, selectedItem.data)
    elif selectedItem.cmd != cmdOk:
      self.broadcastCommand(selectedItem.cmd, selectedItem.data)
  else:
    let result = self.executeView(selectedItem.childBox, 3, selectedIndex+1)
    if result.cmd == cmdCancel:
      self.modified()
      return
    if self.isExecuting:
      self.stopExecutingWith(result.cmd, result.data)
    elif selectedItem.cmd != cmdOk:
      self.broadcastCommand(result.cmd, result.data)

proc handleKey*(self: PSelectBox, event: PEvent) =
  case event.key:
  of TKey.KeyArrowDown:
    self.selectedIndex += 1
    if self.selectedIndex >= self.items.len:
      self.selectedIndex = 0
    self.modified()
    event.setProcessed()
  of TKey.KeyArrowUp:
    self.selectedIndex -= 1
    if self.selectedIndex < 0:
      self.selectedIndex = self.items.len-1
    self.modified()
    event.setProcessed()
  of TKey.KeyEnter:
    self.handleItemSelection(self.selectedIndex)
    event.setProcessed()
  of TKey.KeyEsc:
    if self.isExecuting:
      self.stopExecuting(cmdCancel)
      event.setProcessed()
  else:
    discard
    
method name(self: PSelectBox): string = "SelectBox"

method handleEvent(self: PSelectBox, event: PEvent) = 
  let openedByOtherView = self.isExecuting
  case event.kind:
  of TEventKind.eventMouseButtonDown:
    if not event.local:
      if openedByOtherView:
        self.stopExecuting(cmdCancel)
        event.setProcessed()
      return
    if self.frame.hasBorder:
      let clickedOnTopBorder = event.localMouseY == 0
      let clickedOnBottomBorder = event.localMouseY > self.items.len
      if clickedOnTopBorder or clickedOnBottomBorder:
        event.setProcessed()
        return
    else:
      if event.localMouseY >= self.items.len:
        event.setProcessed()
        return
    let clickedIndex = self.getClickedItemIndex(event.localMouseY)
    self.selectedIndex = clickedIndex
    self.handleItemSelection(clickedIndex)
    event.setProcessed()
  of TEventKind.eventMouseMove:
    if openedByOtherView and event.local and (self.frame.hasBorder == false or event.localMouseY > 0):
      let onMouseOverIndex = self.getClickedItemIndex(event.localMouseY)
      self.selectedIndex = onMouseOverIndex
      self.modified()
  of TEventKind.eventKey:
    self.handleKey(event)
  else:
    discard

proc drawItemTo*(self: PSelectBox, data: ref TObject, buff: var TDrawBuffer) = 
  self.selectBoxItemDrawerFunc(self, data, 0, false, buff)

proc getItem*(self: PSelectBox, index: int): ref TObject = self.items[index].data

proc getItemWidth*(self: PSelectBox, data: ref TObject): int =
  result = self.selectBoxItemWidthFunc(self, data)

method draw(self: PSelectBox): TDrawBuffer = 
  self.frame.draw(self, self.buff)
  var yOffset = if self.frame.hasBorder: 1 else: 0
  for i, item in self.items:
    let selected = self.selectedIndex == i
    self.selectBoxItemDrawerFunc(self, item.data, yOffset+i, selected, self.buff)
  return self.buff

proc init(self: ref TSelectBox,
                      title: string, 
                      selectBoxItemWidthFunc: TSelectBoxItemWidthFunc, 
                      selectBoxItemDrawerFunc: TSelectBoxItemDrawerFunc, 
                      hasBorder: bool = true) = 
  let w = if hasBorder: title.len+2 else: 0
  let h = if hasBorder: 2 else: 0
  self.setWidthHeight(w, h)
  self.frame = (title: title, hasBorder: hasBorder)
  self.items = @[]
  self.selectBoxItemWidthFunc = selectBoxItemWidthFunc
  self.selectBoxItemDrawerFunc = selectBoxItemDrawerFunc

proc createSelectBox*(title: string, 
                      selectBoxItemWidthFunc: TSelectBoxItemWidthFunc, 
                      selectBoxItemDrawerFunc: TSelectBoxItemDrawerFunc, 
                      hasBorder: bool = true): PSelectBox = 
  result = new TSelectBox
  result.init(title, selectBoxItemWidthFunc, selectBoxItemDrawerFunc, hasBorder)

proc calcViewSizeForItemList*(title: string, items: openarray[string]): tuple[x, y: int] = 
  var maxWidth = 0
  for item in items:
    let w = item.len
    if w > maxWidth:
      maxWidth = w
  if maxWidth < title.len+2:
    maxWidth = title.len+2
  return (maxWidth+2, items.len+2)


proc addItem*[T](self: PSelectBox, data: T, cmd: TCmd): PSelectItem = 
  let selectItem = new(TSelectItem)
  selectItem.data = cast[ref TObject](data)
  selectItem.cmd = cmd
  selectItem.rootBox = self
  self.items.add(selectItem)

  var w = self.selectBoxItemWidthFunc(self, selectItem.data) + 2
  if self.w > w:
    w = self.w

  self.setWidthHeight(w, self.h + 1)
  self.modified()
  return selectItem

proc addItem*(self: PSelectBox, data: string, cmd: TCmd): PSelectItem = 
  self.addItem(newString(data), cmd)

proc addItem*(self: PSelectItem, data: string, cmd: TCmd): PSelectItem = 
  if self.childBox == nil:
    self.childBox = createSelectBox($cast[PUTFString](self.data),
                                    self.rootBox.selectBoxItemWidthFunc,
                                    self.rootBox.selectBoxItemDrawerFunc,
                                    self.rootBox.frame.hasBorder)
  return self.childBox.addItem(data, cmd)

type
  TStringifyFunc = proc(data: ref TObject): string
  TStringSelectBox = object of TSelectBox
    stringifyFunc: TStringifyFunc

proc selectBoxStringItemWidth(self: PSelectBox, data: ref TObject): int =
  return cast[ref TStringSelectBox](self).stringifyFunc(data).len

proc selectBoxStringItemDrawer(self: PSelectBox, data: ref TObject, yIndex: int, selected: bool, buff: var TDrawBuffer) =
  let bg = 
    if selected:
      ColorRed
    else:
      FrameColor.color(self.isFocused)  
  let str = cast[ref TStringSelectBox](self).stringifyFunc(data)
  buff.writeText(1, yIndex, str, bg = bg)

proc stringifyFuncForUtfStrings(data: ref TObject): string  {.procvar.} =
  result = $cast[PUTFString](data)


proc createStringSelectBox*(title: string, hasBorder: bool = true, stringifyFunc: TStringifyFunc = stringifyFuncForUtfStrings): PSelectBox =
  let ret = new TStringSelectBox
  ret.init(title, selectBoxStringItemWidth, selectBoxStringItemDrawer, hasBorder)
  ret.stringifyFunc = stringifyFunc
  result = ret


when isMainModule:
  import unittest

  suite "selectbox":

    setup:
      var selectBox = createStringSelectBox("title")
      discard selectBox.addItem("1", cmdOk)
      discard selectBox.addItem("2", cmdOk)
      discard selectBox.addItem("3", cmdOk)

      var unFramedSelectBox = createStringSelectBox("title", false)
      discard unFramedSelectBox.addItem("1", cmdOk)
      discard unFramedSelectBox.addItem("2", cmdOk)
      discard unFramedSelectBox.addItem("3", cmdOk)

    test "calcViewSizeForItemList must return enough space for title":
      let title = "123éáűúőóüö45678"
      let a = calcViewSizeForItemList(title, ["1", "23"])
      check a.x == title.len + 4
      check a.y == 4

    test "calcViewSizeForItemList must return enough space for the longest item":
      let item = "123éáűúőóüö45678"
      let a = calcViewSizeForItemList("1", [item, "23"])
      check a.x == item.len + 2
      check a.y == 4

    test "Selectbox's size changes according to its items":
      selectBox = createStringSelectBox("1")
      check selectBox.w == "1".len + 2
      check selectBox.h == 2

      discard selectBox.addItem("12", cmdOk)
      check selectBox.w == "12".len + 2
      check selectBox.h == 3
      discard selectBox.addItem("1234567", cmdOk)
      check selectBox.w == "1234567".len + 2
      check selectBox.h == 4

      discard selectBox.addItem("123", cmdOk)
      check selectBox.w == "1234567".len + 2
      check selectBox.h == 5

    test "frameless Selectbox's size changes according to its items":
      selectBox = createStringSelectBox("title", false)
      discard selectBox.addItem("1", cmdOk)
      check selectBox.w == "1".len + 2
      check selectBox.h == 1
      discard selectBox.addItem("1234567", cmdOk)
      check selectBox.w == "1234567".len + 2
      check selectBox.h == 2

      discard selectBox.addItem("123", cmdOk)
      check selectBox.w == "1234567".len + 2
      check selectBox.h == 3

    test "Adding items makes the box dirty":
      selectBox = createStringSelectBox("title")
      selectBox.settingDirtyToFalseForTestingPurposes()
      discard selectBox.addItem("1", cmdOk)
      check selectBox.dirty == true

    test "handle down key":
      check selectBox.selectedIndex == 0
      selectBox.settingDirtyToFalseForTestingPurposes()
      selectBox.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowDown))
      check selectBox.selectedIndex == 1
      check selectBox.dirty == true
      selectBox.settingDirtyToFalseForTestingPurposes()
      selectBox.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowDown))
      check selectBox.selectedIndex == 2
      check selectBox.dirty == true
      selectBox.settingDirtyToFalseForTestingPurposes()
      selectBox.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowDown))
      check selectBox.selectedIndex == 0
      check selectBox.dirty == true

    test "handle up key":
      check selectBox.selectedIndex == 0
      selectBox.settingDirtyToFalseForTestingPurposes()
      selectBox.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowUp))
      check selectBox.selectedIndex == 2
      check selectBox.dirty == true
      selectBox.settingDirtyToFalseForTestingPurposes()
      selectBox.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowUp))
      check selectBox.selectedIndex == 1
      check selectBox.dirty == true
      selectBox.settingDirtyToFalseForTestingPurposes()
      selectBox.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowUp))
      check selectBox.selectedIndex == 0
      check selectBox.dirty == true
      
    test "child boxes inherit frame properties":
      let selectBox1 = createStringSelectBox("title")
      let item1 = selectBox1.addItem("1", cmdOk)
      discard item1.addItem("1", cmdOk)
      check item1.childBox.frame.hasBorder == true

      let selectBox2 = createStringSelectBox("title", false)
      let item2 = selectBox2.addItem("2", cmdOk)
      discard item2.addItem("2", cmdOk)
      check item2.childBox.frame.hasBorder == false
      
    test "All child boxes have a reference to their ancestor":
      let selectBox1 = createStringSelectBox("title")
      let item1 = selectBox1.addItem("1", cmdOk)
      let item2 = selectBox1.addItem("2", cmdOk)
      let subItem1 = item1.addItem("11", cmdOk)
      let subSubItem1 = subItem1.addItem("111", cmdOk)
      discard selectBox1.draw()

      check item1.rootBox == selectBox1
      check item2.rootBox == selectBox1
      check subItem1.rootBox == item1.childBox
      check subSubItem1.rootBox == subItem1.childBox
      
    test "inheritance":
      let view: PView = createStringSelectBox("title")
      check "SelectBox" == view.name
      discard view.draw()

    test "Ignores mouse clicks outside its area":
      let event = PEvent(kind: TEventKind.eventMouseButtonDown, localMouseX: 10, localMouseY: 10)
      selectBox.handleEvent(event)
      check event.kind == TEventKind.eventMouseButtonDown

    test "UnFramed box: selecting items with mouse":
      check unFramedSelectBox.selectedIndex == 0
      unFramedSelectBox.settingDirtyToFalseForTestingPurposes()
      var event = PEvent(kind: TEventKind.eventMouseButtonDown, local:true, localMouseX: 1, localMouseY: 2)
      unFramedSelectBox.handleEvent(event)
      check unFramedSelectBox.selectedIndex == 2

      event = PEvent(kind: TEventKind.eventMouseButtonDown, local:true, localMouseX: 1, localMouseY: 1)
      unFramedSelectBox.handleEvent(event)
      check unFramedSelectBox.selectedIndex == 1

      event = PEvent(kind: TEventKind.eventMouseButtonDown, local:true, localMouseX: 1, localMouseY: 0)
      unFramedSelectBox.handleEvent(event)
      check unFramedSelectBox.selectedIndex == 0

      event = PEvent(kind: TEventKind.eventMouseButtonDown, local:true, localMouseX: 1, localMouseY: 4)
      unFramedSelectBox.handleEvent(event)
      check unFramedSelectBox.selectedIndex == 0

    test "Frame box: selecting items with mouse":
      check selectBox.selectedIndex == 0
      selectBox.settingDirtyToFalseForTestingPurposes()
      var event = PEvent(kind: TEventKind.eventMouseButtonDown, local:true, localMouseX: 1, localMouseY: 3)
      selectBox.handleEvent(event)
      check selectBox.selectedIndex == 2

      event = PEvent(kind: TEventKind.eventMouseButtonDown, local:true, localMouseX: 1, localMouseY: 2)
      selectBox.handleEvent(event)
      check selectBox.selectedIndex == 1

      event = PEvent(kind: TEventKind.eventMouseButtonDown, local:true, localMouseX: 1, localMouseY: 0)
      selectBox.handleEvent(event)
      check selectBox.selectedIndex == 1

      event = PEvent(kind: TEventKind.eventMouseButtonDown, local:true, localMouseX: 1, localMouseY: 4)
      selectBox.handleEvent(event)
      check selectBox.selectedIndex == 1

      event = PEvent(kind: TEventKind.eventMouseButtonDown, local:true, localMouseX: 1, localMouseY: 1)
      selectBox.handleEvent(event)
      check selectBox.selectedIndex == 0