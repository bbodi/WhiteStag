import unicode

import view
import frame
import color
import drawbuffer
import event
import option
import rect
import utfstring

type
  PRadioGroup* = ref TRadioGroup
  TRadioGroup* = object of TView
    frame: TWindowFrame
    selectedIndex: int
    items: seq[PUTFString]
    data*: PUTFString

proc drawItem*(self: PRadioGroup, item: PUTFString, index: int, buff: var TDrawBuffer) = 
  let selected = index == self.selectedIndex
  var text = (if selected: "(*) " else: "( ) ") & item
  let yOffset = if self.frame.hasBorder: 1 else: 0
  buff.writeText(1, yOffset+index, text, fg = PanelTextColor.color(selected))

proc getClickedItemIndex(self: PRadioGroup, mouseY: int): int = 
  let firstItemIndex = if self.frame.hasBorder: 1 else: 0
  return mouseY - firstItemIndex

proc handleMouse(self: PRadioGroup, event: PEvent) =
  discard

proc selectItem*(self: PRadioGroup, index: int) =
  self.selectedIndex = index
  self.data = self.items[index]
  self.modified()

proc handleKey*(self: PRadioGroup, event: PEvent) =
  case event.key:  
  of TKey.KeyArrowDown:
    if self.selectedIndex == self.items.len - 1:
      self.selectItem(0)
    else:
      self.selectItem(self.selectedIndex + 1)
    event.setProcessed()
  of TKey.KeyArrowUp:
    if self.selectedIndex == 0:
      self.selectItem(self.items.len-1)
    else:
      self.selectItem(self.selectedIndex - 1)
    event.setProcessed()
  of TKey.KeyEsc:
    discard
  else:
    discard
    
method name*(self: PRadioGroup): string = "RadioGroup"

method handleEvent*(self: PRadioGroup, event: PEvent) = 
  case event.kind:
  of TEventKind.eventMouseButtonDown:
    if event.local:
      let selectedIndex = self.getClickedItemIndex(event.localMouseY)
      self.selectItem(selectedIndex)
      event.setProcessed()
      
  of TEventKind.eventKey:
    self.handleKey(event)
  else:
    discard

method draw*(self: PRadioGroup): TDrawBuffer = 
  self.frame.draw(self, self.buff)
  self.buff.setCells(0, 0, self.w, self.h, bg = PanelColor.color(self.isFocused))
  for i, item in self.items:
    self.drawItem(item, i, self.buff)
  return self.buff

proc createRadioGroup(title: string, hasBorder: bool): PRadioGroup = 
  result = new(TRadioGroup)
  result.frame = (title: title, hasBorder: hasBorder)
  result.items = @[]

proc createRadioGroupWithFrame*(title: string): PRadioGroup = 
  return createRadioGroup(title, true)

proc createRadioGroupWithoutFrame*(): PRadioGroup = 
  return createRadioGroup("", false)

proc calcViewSizeForItemList(title: string, items: openarray[PUTFString]): tuple[x, y: int] = 
  var maxWidth = 0
  for item in items:
    let w = item.len
    if w > maxWidth:
      maxWidth = w
  if maxWidth < title.len+2:
    maxWidth = title.len+2
  let yOffset = if title == "": 0 else: 2
  return (maxWidth+5, items.len+yOffset)

proc addItem*(self: PRadioGroup, data: PUTFString) = 
  self.items.add(data)
  let title = if self.frame.hasBorder: self.frame.title else: ""
  let newSize = calcViewSizeForItemList(title, self.items)
  self.setWidthHeight(newSize.x, newSize.y)

when isMainModule:
  import unittest

  test "calcViewSizeForItemList must return enough space for title":
    let title = "123éáűúőóüö45678"
    let a = calcViewSizeForItemList(title, [utf"1", utf"23"])
    check a.x == title.len + " [ ] ".len + 2
    check a.y == 4

  test "calcViewSizeForItemList must return enough space for the longest item":
    let item = utf"123éáűúőóüö45678"
    let a = calcViewSizeForItemList("1", [item, utf"23"])
    check a.x == item.len + " [ ] ".len
    check a.y == 4

  test "handle down key":
    var radioGroup = createRadioGroupWithFrame("title")
    radioGroup.addItem(utf"1")
    radioGroup.addItem(utf"2")
    radioGroup.addItem(utf"3")
    check radioGroup.selectedIndex == 0
    check radioGroup.dirty == false
    radioGroup.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowDown))
    check radioGroup.selectedIndex == 1
    radioGroup.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowDown))
    check radioGroup.selectedIndex == 2
    radioGroup.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowDown))
    check radioGroup.selectedIndex == 0
    check radioGroup.dirty == true

  test "handle up key":
    var radioGroup = createRadioGroupWithFrame("title")
    radioGroup.addItem(utf"1")
    radioGroup.addItem(utf"2")
    radioGroup.addItem(utf"3")
    check radioGroup.selectedIndex == 0
    check radioGroup.dirty == false
    radioGroup.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowUp))
    check radioGroup.selectedIndex == 2
    radioGroup.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowUp))
    check radioGroup.selectedIndex == 1
    radioGroup.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowUp))
    check radioGroup.selectedIndex == 0
    check radioGroup.dirty == true
    
  test "inheritance":
    let view: PView = createRadioGroupWithFrame("title")
    check "RadioGroup" == view.name
    discard view.draw()

  test "Ignores mouse clicks outside its area":
    var radioGroup = createRadioGroupWithFrame("title")
    radioGroup.addItem(utf"1")
    radioGroup.addItem(utf"2")
    radioGroup.addItem(utf"3")
    let event = PEvent(kind: TEventKind.eventMouseButtonDown, localMouseX: 10, localMouseY: 10)
    radioGroup.handleEvent(event)
    check event.kind == TEventKind.eventMouseButtonDown

  test "getClickedItemIndex":
    let radioGroupWithTitle: PRadioGroup = createRadioGroupWithFrame("title")
    check radioGroupWithTitle.getClickedItemIndex(2) == 1
    check radioGroupWithTitle.getClickedItemIndex(3) == 2

    let radioGroupWithoutTitle: PRadioGroup = createRadioGroupWithoutFrame()
    check radioGroupWithoutTitle.getClickedItemIndex(2) == 2
    check radioGroupWithoutTitle.getClickedItemIndex(3) == 3