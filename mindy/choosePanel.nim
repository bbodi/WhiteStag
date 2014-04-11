import ../WhiteStagEditor/view
import ../WhiteStagEditor/textarea
import ../WhiteStagEditor/checkboxgroup
import ../WhiteStagEditor/panel
import ../WhiteStagEditor/utfstring

import types


type
  TChoosePanelQuestionUi* = object of TQuestionUi
    problemStatementTextArea: PTextArea
    inputFields: seq[PTextArea]
    checkboxes: PCheckboxGroup

method fillEditorPanel*(self: ref TChoosePanelQuestionUi, panel: PPanel, question: ref TQuestion) =
  self.problemStatementTextArea = createTextArea(panel.w - 2, 8)
  panel.addView(self.problemStatementTextArea, 0, 0)
  
  var inputFieldsPanel = createPanel(30, 5)
  self.checkboxes = createCheckBoxGroupWithoutFrame()
  self.checkboxes.addItem(utf"")
  self.checkboxes.addItem(utf"")
  self.checkboxes.addItem(utf"")
  self.checkboxes.addItem(utf"")
  self.checkboxes.addItem(utf"")
  self.checkboxes.addItem(utf"")


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

  inputFieldsPanel.addView(self.checkboxes, 0, 0)
  inputFieldsPanel.addView(input0, 4, 0)
  inputFieldsPanel.addView(input1, 4, 1)
  inputFieldsPanel.addView(input2, 4, 2)
  inputFieldsPanel.addView(input3, 4, 3)
  inputFieldsPanel.addView(input4, 4, 4)
  inputFieldsPanel.addView(input5, 4, 5)

  self.inputFields = @[]
  self.inputFields.add(input0)
  self.inputFields.add(input1)
  self.inputFields.add(input2)
  self.inputFields.add(input3)
  self.inputFields.add(input4)
  self.inputFields.add(input5)

  panel.addView(inputFieldsPanel, 2, self.problemStatementTextArea.y2+2)

  if question != nil:
    discard

  self.problemStatementTextArea.setFocused()

method createQuestionFromInput*(self: ref TChoosePanelQuestionUi): ref TQuestion = 
  result = new TQuestion
  result.problemStatement = self.problemStatementTextArea.utftext
  result.answers = @[]
  for inputField in self.inputFields:
    let text = inputField.utftext
    if text.len == 0:
      continue
    result.answers.add(text)