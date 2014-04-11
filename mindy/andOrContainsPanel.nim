import ../WhiteStagEditor/view
import ../WhiteStagEditor/textarea
import ../WhiteStagEditor/radiogroup
import ../WhiteStagEditor/panel
import ../WhiteStagEditor/utfstring

import types


type
  TAndOrContainsQuestionUi* = object of TQuestionUi
    problemStatementTextArea: PTextArea
    inputFields: seq[PTextArea]
    qtypeRadioGrp: PRadioGroup

method fillEditorPanel*(self: ref TAndOrContainsQuestionUi, panel: PPanel, question: ref TQuestion) =
  self.qtypeRadioGrp = createRadioGroupWithoutFrame()
  self.qtypeRadioGrp.addItem(utf"And")
  self.qtypeRadioGrp.addItem(utf"Or")
  self.qtypeRadioGrp.addItem(utf"Contains")
  panel.addView(self.qtypeRadioGrp, panel.w - 2 - self.qtypeRadioGrp.w, 0)

  self.problemStatementTextArea = createTextArea(panel.w - 2 - self.qtypeRadioGrp.w - 2, 13)
  panel.addView(self.problemStatementTextArea, 0, 0)
  
  var inputFieldsPanel = createPanel(30, 5)
  let inputW = panel.w div 2 - 4
  var input0 = createTextArea(inputW, 1)
  input0.dontHandleControlKeys = true
  var input1 = createTextArea(inputW, 1)
  input1.dontHandleControlKeys = true
  var input2 = createTextArea(inputW, 1)
  input2.dontHandleControlKeys = true
  var input3 = createTextArea(inputW, 1)
  input3.dontHandleControlKeys = true
  var input4 = createTextArea(inputW, 1)
  input4.dontHandleControlKeys = true
  var input5 = createTextArea(inputW, 1)
  input5.dontHandleControlKeys = true
  inputFieldsPanel.addView(input0, 0, 0)
  inputFieldsPanel.addView(input1, 0, 2)
  inputFieldsPanel.addView(input2, 0, 4)

  inputFieldsPanel.addView(input3, 4 + inputW, 0)
  inputFieldsPanel.addView(input4, 4 + inputW, 2)
  inputFieldsPanel.addView(input5, 4 + inputW, 4)
  self.inputFields = @[]
  self.inputFields.add(input0)
  self.inputFields.add(input1)
  self.inputFields.add(input2)
  self.inputFields.add(input3)
  self.inputFields.add(input4)
  self.inputFields.add(input5)

  panel.addView(inputFieldsPanel, 2, self.problemStatementTextArea.y2+2)

  if question != nil:
    for i, answer in question.answers:
      self.inputFields[i].text = $answer
    self.problemStatementTextArea.text = $question.problemStatement
    self.qtypeRadioGrp.selectItem(int(question.kind))

  self.problemStatementTextArea.setFocused()

method createQuestionFromInput*(self: ref TAndOrContainsQuestionUi): ref TQuestion = 
  result = new TQuestion
  result.problemStatement = self.problemStatementTextArea.utftext
  case cast[string](self.qtypeRadioGrp.data):
  of "And": 
    result.kind = qtypeAnd
  of "Or": 
    result.kind = qtypeOr
  of "Contains": 
    result.kind = qtypeContains
  result.answers = @[]
  for inputField in self.inputFields:
    let text = inputField.utftext
    if text.len == 0:
      continue
    result.answers.add(text)