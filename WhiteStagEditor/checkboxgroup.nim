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
  PRadioGroup* = ref TRadioButton
  TRadioButton* = object of TView
    frame: TWindowFrame
    currentRow: int
    items: seq[pointer]
    selectedIndices: seq[bool]
    itemDrawer*: PItemDrawer

proc drawItem*(self: PRadioGroup, item: pointer, index: int, buff: var TDrawBuffer) = 
  let selected = self.selectedIndices[index]
  var text = (if selected: "[X] " else: "[ ] ") & self.itemDrawer.itemToString(item)
  let yOffset = if self.frame.hasBorder: 1 else: 0
  buff.writeText(1, yOffset+index, text, fg = PanelTextColor.color(selected))

proc getClickedItemIndex(self: PRadioGroup, mouseY: int): int = 
  let firstItemIndex = if self.frame.hasBorder: 1 else: 0
  return mouseY - firstItemIndex

proc handleMouse(self: PRadioGroup, event: PEvent) =
  discard

proc handleKey*(self: PRadioGroup, event: PEvent) =
  case event.key:  
  of TKey.KeyArrowDown:
    self.currentRow += 1
    if self.currentRow >= self.items.len:
      self.currentRow = 0
    self.modified()
    event.setProcessed()
  of TKey.KeyArrowUp:
    self.currentRow -= 1
    if self.currentRow < 0:
      self.currentRow = self.items.len-1
    self.modified()
    event.setProcessed()
  of TKey.KeyEsc:
    discard
  else:
    discard

proc isChecked(self: PRadioGroup, index: int): bool = self.selectedIndices[index]
    
method name*(self: PRadioGroup): string = "CheckboxGroup"

method handleEvent*(self: PRadioGroup, event: PEvent) = 
  case event.kind:
  of TEventKind.eventMouseButtonDown:
    let clickedOnItem1 = (self.frame.hasBorder == false or event.localMouseY > 0)
    let clickedOnItem2 = (self.frame.hasBorder == false or event.localMouseY <= self.items.len)
    if event.local and clickedOnItem1 and clickedOnItem2:
      let currentRow = self.getClickedItemIndex(event.localMouseY)
      self.currentRow = currentRow
      self.selectedIndices[currentRow] = not self.selectedIndices[currentRow]
      event.setProcessed()
      self.modified()
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
  result = new(TRadioButton)
  result.frame = (title: title, hasBorder: hasBorder)
  result.items = @[]
  result.itemDrawer = PStringItemDrawer()
  result.selectedIndices = @[]

proc createCheckBoxGroupWithFrame*(title: string): PRadioGroup = 
  return createRadioGroup(title, true)

proc createCheckBoxGroupWithoutFrame*(): PRadioGroup = 
  return createRadioGroup("", false)

proc calcViewSizeForItemList(title: string, items: openarray[string]): tuple[x, y: int] = 
  var maxWidth = 0
  for item in items:
    let w = item.len
    if w > maxWidth:
      maxWidth = w
  if maxWidth < title.len+2:
    maxWidth = title.len+2
  let yOffset = if title == "": 0 else: 2
  return (maxWidth+5, items.len+yOffset)

proc addItem*[T](self: PRadioGroup, data: T) = 
  if T is string:
    self.itemDrawer = PStringItemDrawer()
  elif T is int:
    self.itemDrawer = PIntItemDrawer()

  self.items.add(cast[pointer](data))
  var itemNames: seq[string] = @[]
  for item in self.items:
    itemNames.add(self.itemDrawer.itemToString(item) )
  let title = if self.frame.hasBorder: self.frame.title else: ""
  let newSize = calcViewSizeForItemList(title, itemNames)
  self.setWidthHeight(newSize.x, newSize.y)
  self.selectedIndices.add(false)

when isMainModule:
  import unittest

  test "calcViewSizeForItemList must return enough space for title":
    let title = "123éáűúőóüö45678"
    let a = calcViewSizeForItemList(title, ["1", "23"])
    check a.x == title.len + " [ ] ".len + 2
    check a.y == 4

  test "calcViewSizeForItemList must return enough space for the longest item":
    let item = "123éáűúőóüö45678"
    let a = calcViewSizeForItemList("1", [item, "23"])
    check a.x == item.len + " [ ] ".len
    check a.y == 4

  test "handle down key":
    var radioGroup = createCheckBoxGroupWithFrame("title")
    radioGroup.addItem("1")
    radioGroup.addItem("2")
    radioGroup.addItem("3")
    check radioGroup.currentRow == 0
    check radioGroup.dirty == false
    radioGroup.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowDown))
    check radioGroup.currentRow == 1
    radioGroup.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowDown))
    check radioGroup.currentRow == 2
    radioGroup.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowDown))
    check radioGroup.currentRow == 0
    check radioGroup.dirty == true

  test "handle up key":
    var radioGroup = createCheckBoxGroupWithFrame("title")
    radioGroup.addItem("1")
    radioGroup.addItem("2")
    radioGroup.addItem("3")
    check radioGroup.currentRow == 0
    check radioGroup.dirty == false
    radioGroup.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowUp))
    check radioGroup.currentRow == 2
    radioGroup.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowUp))
    check radioGroup.currentRow == 1
    radioGroup.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowUp))
    check radioGroup.currentRow == 0
    check radioGroup.dirty == true
    
  test "inheritance":
    let view: PView = createCheckBoxGroupWithFrame("title")
    check "CheckboxGroup" == view.name
    discard view.draw()

  test "Ignores mouse clicks outside its area":
    var radioGroup = createCheckBoxGroupWithFrame("title")
    radioGroup.addItem("1")
    radioGroup.addItem("2")
    radioGroup.addItem("3")
    let event = PEvent(kind: TEventKind.eventMouseButtonDown, localMouseX: 10, localMouseY: 10)
    radioGroup.handleEvent(event)
    check event.kind == TEventKind.eventMouseButtonDown

  test "getClickedItemIndex":
    let radioGroupWithTitle: PRadioGroup = createCheckBoxGroupWithFrame("title")
    check radioGroupWithTitle.getClickedItemIndex(2) == 1
    check radioGroupWithTitle.getClickedItemIndex(3) == 2

    let radioGroupWithoutTitle: PRadioGroup = createCheckBoxGroupWithoutFrame()
    check radioGroupWithoutTitle.getClickedItemIndex(2) == 2
    check radioGroupWithoutTitle.getClickedItemIndex(3) == 3