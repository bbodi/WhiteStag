import os

import ../WhiteStagEditor/window
import ../WhiteStagEditor/sdlengine
import ../WhiteStagEditor/view
import ../WhiteStagEditor/pixel
import ../WhiteStagEditor/option
import ../WhiteStagEditor/desktop
import ../WhiteStagEditor/selectbox
import ../WhiteStagEditor/event
import ../WhiteStagEditor/scrollableViewWrapper
import ../WhiteStagEditor/scrollbar
import ../WhiteStagEditor/progressbar
import ../WhiteStagEditor/button
import ../WhiteStagEditor/radiogroup
import ../WhiteStagEditor/checkboxgroup
import ../WhiteStagEditor/textfield
import ../WhiteStagEditor/tree
import ../WhiteStagEditor/stringtree
import ../WhiteStagEditor/dialog
import ../WhiteStagEditor/list
import ../WhiteStagEditor/textarea
import ../WhiteStagEditor/panel
import ../WhiteStagEditor/combobox
import ../WhiteStagEditor/utfstring
import ../WhiteStagEditor/label

import types
import db

type
  TQuestionUi = object of TObject
  TAndOrContainsQuestionUi = object of TQuestionUi
    problemStatementTextArea: PTextArea
    inputFields: seq[PTextArea]
    qtypeRadioGrp: PCheckboxGroup

  TMindy* = object of TApplication
    currentQuestionUi: ref TQuestionUi
    question: ref TQuestion


const
  chooseTypeAndOrContainsCmd = TCmd("chooseTypeAndOrContainsCmd")
  chooseTypeControlledSkippingCmd = TCmd("chooseTypeControlledSkippingCmd")
  chooseTypeRandomSkippingCmd = TCmd("chooseTypeRandomSkippingCmd")
  chooseTypeTrueFalseCmd = TCmd("chooseTypeTrueFalseCmd")
  chooseTypeMirrorCmd = TCmd("chooseTypeMirrorCmd")

  cmdEditQuestionOk = TCmd("cmdEditQuestionOk")
  cmdEditQuestionExpl = TCmd("cmdEditQuestionExpl")
  cmdEditQuestionCancel = TCmd("cmdEditQuestionCancel")
  cmdEditQuestionHistory = TCmd("cmdEditQuestionHistory")

  cmdChangeQuestionType = TCmd("cmdChangeQuestionType")
  cmdTagChoosed = TCmd("cmdTagChoosed")
  W = 80
  H = 40


method fillEditorPanel(self: ref TQuestionUi, panel: PPanel, question: ref TQuestion) = quit "to override!"
method createQuestionFromInput(self: ref TQuestionUi): ref TQuestion = quit "to override!"

method fillEditorPanel(self: ref TAndOrContainsQuestionUi, panel: PPanel, question: ref TQuestion) =
  self.qtypeRadioGrp = createRadioGroupWithoutFrame()
  self.qtypeRadioGrp.addItem("And")
  self.qtypeRadioGrp.addItem("Or")
  self.qtypeRadioGrp.addItem("Contains")
  panel.addView(self.qtypeRadioGrp, panel.w - 2 - self.qtypeRadioGrp.w, 0)

  self.problemStatementTextArea = createTextArea(panel.w - 2 - self.qtypeRadioGrp.w - 2, 13)
  panel.addView(self.problemStatementTextArea, 0, 0)
  
  var inputFieldsPanel = createPanel(30, 5)
  let inputW = panel.w div 2 - 4
  var input0 = createTextArea(inputW, 1)
  var input1 = createTextArea(inputW, 1)
  var input2 = createTextArea(inputW, 1)
  var input3 = createTextArea(inputW, 1)
  var input4 = createTextArea(inputW, 1)
  var input5 = createTextArea(inputW, 1)
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

  panel.addView(inputFieldsPanel, 2, 15)

  if question != nil:
    for i, answer in question.answers:
      self.inputFields[i].text = $answer
    self.problemStatementTextArea.text = $question.problemStatement
    self.qtypeRadioGrp.selectItem(int(question.kind))

  self.problemStatementTextArea.setFocused()

method createQuestionFromInput(self: ref TAndOrContainsQuestionUi): ref TQuestion = 
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


var questionPanel: PPanel
var questionEditorWindow = createWindow(W - 5, H - 5, "Adding new question")
questionEditorWindow.closeable = false
questionEditorWindow.resizable = true
questionEditorWindow.growMode = {}

var questionTypeSelectBox = createStringSelectBox("Type")
discard questionTypeSelectBox.addItem("And, Or, Contains", cmdChangeQuestionType)
discard questionTypeSelectBox.addItem("Controlled skipping", cmdChangeQuestionType)
discard questionTypeSelectBox.addItem("Random skipping", cmdChangeQuestionType)
discard questionTypeSelectBox.addItem("True-false", cmdChangeQuestionType)
discard questionTypeSelectBox.addItem("Mirror", cmdChangeQuestionType)
var questionTypeComboBox = createComboBox("Type", questionTypeSelectBox)

questionEditorWindow.addView(questionTypeComboBox, 3, 1)

var tagInputField = createTextArea(10, 1)
var tagSelectBox = createStringSelectBox("Tag history")
discard tagSelectBox.addItem("java", cmdTagChoosed)
discard tagSelectBox.addItem("izom", cmdTagChoosed)
discard tagSelectBox.addItem("általános", cmdTagChoosed)

questionEditorWindow.addView(tagInputField, 3, questionEditorWindow.h - 5)
questionEditorWindow.addView(createLabel("(Press ctrl+h for tag history)"), tagInputField.x2 + 2, questionEditorWindow.h - 5)

var okBtn = createButton("Ok", cmdEditQuestionOk)
var explBtn = createButton("Magyarázat", cmdEditQuestionExpl)
var cancelBtn = createButton("Mégse", cmdEditQuestionCancel)
var historyBtn = createButton("Előzmények", cmdEditQuestionHistory)
questionEditorWindow.addView(okBtn, 3, questionEditorWindow.h - 3)
questionEditorWindow.addView(explBtn, okBtn.x2 + 2, questionEditorWindow.h - 3)
questionEditorWindow.addView(cancelBtn, explBtn.x2 + 2, questionEditorWindow.h - 3)
questionEditorWindow.addView(historyBtn, cancelBtn.x2 + 2, questionEditorWindow.h - 3)



var menuWindow = createWindow(35, 10, "Projects")
menuWindow.closeable = false
menuWindow.resizable = false
menuWindow.growMode = {}

var application = new(TMindy)

var deskt = createDesktop(application, 80, 40, 14)
deskt.addViewAtCenter(menuWindow)

var usersMenu = createStringSelectBox("Balázs", false)
discard usersMenu.addItem("Új felhasználó...", TCmd("createUserButton"))
for fileName in walkFiles("*.db"):
  let dbName = fileName[0..fileName.len-4]
  discard usersMenu.addItem(dbName, TCmd("switchUserButton"))


var switchUserComboBox = createComboBox("Felhasználó váltása", usersMenu)
var startButton = createButton("Kezdés", TCmd("Start"))
var newButton = createButton("Új hozzáadása", TCmd("addNewQuestion"))
var editButton = createButton("Szerkesztés", TCmd("Start"))
var exitButton = createButton("Kilépés", cmdQuit)
menuWindow.addViewAtCenter(switchUserComboBox, -3)
menuWindow.addViewAtCenter(startButton, -1)
menuWindow.addViewAtCenter(newButton, 0)
menuWindow.addViewAtCenter(editButton, 1)
menuWindow.addViewAtCenter(exitButton, 2)

discard deskt.execute()

proc addQuestionPanel(self: ref TMindy) = 
  questionPanel = createPanel(questionEditorWindow.w-2, questionEditorWindow.h - 3 - 5)
  self.currentQuestionUi.fillEditorPanel(questionPanel, self.question)
  questionEditorWindow.addView(questionPanel, 1, 3)
  if self.question != nil:
    tagInputField.text = $self.question.tag

proc selectUser(self: ref TMindy, username: string) =
  var dao = createDao(username)
      
  menuWindow.title = username
  menuWindow.modified()

method handleEvent(self: ref TMindy, event: PEvent) = 
  case event.kind:
  of TEventKind.eventKey:
    if event.pressedCtrl('h'):
      event.setProcessed()
      let result = deskt.executeViewAtCenter(tagSelectBox)
      if result.cmd == cmdCancel:
        return
      let tag = cast[PUTFString](result.data)
      tagInputField.text = $tag
  of TEventKind.eventCommand:
    case event.cmd:
    of TCmd("createUserButton"):
      event.setProcessed()
      let username = deskt.showStringDialog("Név")
      discard usersMenu.addItem(username, TCmd("switchUserButton"))
      self.selectUser(username)
    of TCmd("switchUserButton"):
      event.setProcessed()
      let username = cast[PUTFString](switchUserComboBox.data)
      self.selectUser($username)
    of TCmd("addNewQuestion"):
      deskt.addViewAtCenter(questionEditorWindow)
      if self.question != nil:
        case self.question.kind:
        of qtypeAnd, qtypeOr, qtypeContains:
          self.currentQuestionUi = new TAndOrContainsQuestionUi 
          self.addQuestionPanel() 
        else:
          discard
    of cmdChangeQuestionType:
      let questionType = cast[PUTFString](questionTypeComboBox.data)
      case $questionType:
      of "And, Or, Contains":
        self.currentQuestionUi = new TAndOrContainsQuestionUi

      self.addQuestionPanel() 
    of cmdEditQuestionCancel:
      if not questionPanel.isNil and questionPanel.hasOwner:
        questionEditorWindow.removeView(questionPanel)
      deskt.removeView(questionEditorWindow)
    of cmdEditQuestionOk:
      self.question = self.currentQuestionUi.createQuestionFromInput()
      self.question.tag = tagInputField.utftext
      questionEditorWindow.removeView(questionPanel)
      deskt.removeView(questionEditorWindow)
  else:
    discard