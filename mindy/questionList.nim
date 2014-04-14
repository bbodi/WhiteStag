import ../WhiteStagEditor/list
import ../WhiteStagEditor/view
import ../WhiteStagEditor/event
import ../WhiteStagEditor/drawbuffer
import ../WhiteStagEditor/color
import ../WhiteStagEditor/utfstring

import types

type
  PQuestionCellView = ref TQuestionCellView
  TQuestionCellView = object of TListCellView
    question: ref TQuestion
    node: PListNode

method setNode*(self: PQuestionCellView, node: PListNode) = 
  self.clearViews()
  self.node = node
  self.question = cast[ref TQuestion](node.data)

method name(self: PQuestionCellView): string = "List-QuestionCellView"

method handleEvent(self: PQuestionCellView, event: PEvent) = 
  case event.kind:
  of TEventKind.eventMouseButtonDown:
    discard
  else:
    discard

method draw(self: PQuestionCellView): TDrawBuffer = 
  let bgColor = 
    if self.node.list.isSelected(self):
      SelectedItemBgColor.color(self.isFocused)
    else:
      PanelColor.color(self.isFocused)
  self.buff.setCells(0, 0, self.w, 1, bg = bgColor)

  let textColor = PanelTextColor.color(self.isFocused)
  self.buff.writeText(0, 0, $self.question.problemStatement.substring(0, 20), fg = textColor)
  return self.buff

proc createQuestionCellView(w, h: int): PListCellView {.procvar.} = 
  result = new TQuestionCellView
  result.setWidthHeight(w, 1)

proc createQuestionList*(w, h: int): PList = createList(createQuestionCellView, w, h)