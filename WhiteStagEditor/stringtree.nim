import unicode

import view
import frame
import color
import drawbuffer
import event
import option
import sdlengine
import rect
import tree
import textfield


type
  PStringCellView* = ref TStringCellView
  TStringCellView* = object of TTreeCellView

  TStringifyMethod = proc(data: pointer): string

  PStringTreeCellViewFactory = ref TStringTreeCellViewFactory
  TStringTreeCellViewFactory = object of TTreeCellViewFactory
    stringifyMethod: TStringifyMethod

proc ptrToStr(data: pointer): string = cast[string](data)

method createCellView*(self: PStringTreeCellViewFactory, w, h: int): PTreeCellView = 
  let cell = new(TStringCellView)
  cell.setWidthHeight(w, 1)
  return cell

method stringify*(self: PStringTreeCellViewFactory, data: pointer): string = 
  self.stringifyMethod(data)

method setNode*(self: PStringCellView, node: PTreeNode) = 
  self.views = @[]
  self.node = node
    
method name(self: PStringCellView): string = "StringCellView"

method handleEvent(self: PStringCellView, event: PEvent) = 
  case event.kind:
  of TEventKind.eventMouseButtonDown:
    if event.local and self.node.hasChild and event.localMouseX == 0:
      self.node.opened = not self.node.opened
      self.modified()
      self.node.tree.changedStructure()
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

method draw(self: PStringCellView): TDrawBuffer = 
  let stringData = self.node.tree.cellViewFactory.stringify(self.node.data)
  self.drawTreeItem(stringData, self.buff)
  result = self.buff

proc createStringTree*(stringifyMethod: TStringifyMethod, w, h: int): PTree = 
  createTree(PStringTreeCellViewFactory(stringifyMethod: stringifyMethod), w, h)

proc createStringTree*(w, h: int): PTree = createStringTree(ptrToStr, w, h)