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
import andOrContainsPanel
import choosePanel
import questionlist

type
  TMindy* = object of TApplication
    currentQuestionUi: ref TQuestionUi
    questions: seq[ref TQuestion]
    dao: ref TDao


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


var questionEditorWindow = createWindow(W - 5, H - 5, "Adding new question")
questionEditorWindow.closeable = false
questionEditorWindow.resizable = true
questionEditorWindow.growMode = {}

var questionPanel = createPanel(questionEditorWindow.w-2, questionEditorWindow.h - 3 - 5)
questionEditorWindow.addView(questionPanel, 1, 3)

var elozmenyekSelectBox = createStringSelectBox("Előzmények", true) do (data) -> string:
    let question = cast[ref TQuestion](data)
    result = $(question.problemStatement.substring(0, 30) & "...")
var elozmenyekComboBox = createComboBox("Előzmények", elozmenyekSelectBox)

var questionTypeSelectBox = createStringSelectBox("Type")
discard questionTypeSelectBox.addItem("And, Or, Contains", cmdChangeQuestionType)
discard questionTypeSelectBox.addItem("Controlled skipping", cmdChangeQuestionType)
discard questionTypeSelectBox.addItem("Random skipping", cmdChangeQuestionType)
discard questionTypeSelectBox.addItem("Choose", cmdChangeQuestionType)
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

questionEditorWindow.addView(okBtn, 3, questionEditorWindow.h - 3)
questionEditorWindow.addView(explBtn, okBtn.x2 + 2, questionEditorWindow.h - 3)
questionEditorWindow.addView(cancelBtn, explBtn.x2 + 2, questionEditorWindow.h - 3)
questionEditorWindow.addView(elozmenyekComboBox, cancelBtn.x2 + 2, questionEditorWindow.h - 3)



var menuWindow = createWindow(35, 10, "Projects")
menuWindow.closeable = false
menuWindow.resizable = false
menuWindow.growMode = {}

var application = new(TMindy)
application.questions = @[]

var deskt = createDesktop(application, 80, 40, 14)
deskt.addViewAtCenter(menuWindow)

var usersMenu = createStringSelectBox("Balázs", false)
discard usersMenu.addItem("Új felhasználó...", TCmd("createUserButton"))
for fileName in walkFiles("*.db"):
  let dbName = fileName[0..fileName.len-4]
  discard usersMenu.addItem(dbName, TCmd("switchUserButton"))


var switchUserComboBox = createComboBox("Felhasználó váltása", usersMenu)
var startButton = createButton("Kezdés", TCmd("Start"))
var newButton = createButton("Új hozzáadása", TCmd("addNewQuestionClicked"))
var editButton = createButton("Szerkesztés", TCmd("listQuestionsClicked"))
var exitButton = createButton("Kilépés", cmdQuit)
menuWindow.addViewAtCenter(switchUserComboBox, -3)
menuWindow.addViewAtCenter(startButton, -1)
menuWindow.addViewAtCenter(newButton, 0)
menuWindow.addViewAtCenter(editButton, 1)
menuWindow.addViewAtCenter(exitButton, 2)

discard deskt.execute()
if application.isNil == false:
  application.dao.close()

proc fillEditQuestionPanel(self: ref TMindy, question: ref TQuestion) = 
  case question.kind:
  of qtypeAnd, qtypeOr, qtypeContains:
    self.currentQuestionUi = new TAndOrContainsQuestionUi
  of qtypeChoose:
    self.currentQuestionUi = new TChoosePanelQuestionUi
  else:
    discard
  self.currentQuestionUi.fillEditorPanel(questionPanel, question)
  if question != nil and not question.tag.isNil:
    tagInputField.text = $question.tag    

proc selectUser(self: ref TMindy, username: string) =
  if application.dao.isNil == false:
    application.dao.close()
  self.dao = createDao(username)
  self.questions = self.dao.findAllQuestion()
  echo repr(self.questions)
      
  menuWindow.title = username
  menuWindow.modified()

proc saveEditedQuestion(self: ref TMindy): ref TQuestion =
  let question = self.currentQuestionUi.createQuestionFromInput()
  question.tag = tagInputField.utftext
  let elozmenyText = question.problemStatement.substring(0, 30) & "..."
  discard elozmenyekSelectBox.addItem(question, TCmd("cmdElozmenyClicked"))
  self.questions.add(question)
  return question

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
    of TCmd("addNewQuestionClicked"):
      deskt.addViewAtCenter(questionEditorWindow)
    of cmdChangeQuestionType:
      let questionType = cast[PUTFString](questionTypeComboBox.data)
      let newQuestion = new TQuestion
      case $questionType:
      of "And, Or, Contains":
        newQuestion.kind = TQuestionKind.qtypeAnd
      of "Choose":
        newQuestion.kind = TQuestionKind.qtypeChoose
      self.fillEditQuestionPanel(newQuestion)
    of cmdEditQuestionCancel:
      if not questionPanel.isNil and questionPanel.hasOwner:
        questionEditorWindow.removeView(questionPanel)
      deskt.removeView(questionEditorWindow)
    of cmdEditQuestionOk:
      let editedQuestion = self.saveEditedQuestion()
      self.dao.insertQuestion(editedQuestion)
      let newQuestion = new TQuestion
      newQuestion.kind = editedQuestion.kind
      self.fillEditQuestionPanel(newQuestion)
    of TCmd("cmdElozmenyClicked"):
      let selectedQuestion = cast[ref TQuestion](elozmenyekComboBox.data)
      self.fillEditQuestionPanel(selectedQuestion)
    of TCmd("listQuestionsClicked"):
      let win = createWindow(W - 5, H - 5, "Question list")
      win.closeable = true
      let list = createQuestionList(win.w-2, win.h-2)
      for q in self.questions:
        list.addItem(q)
      deskt.addViewAtCenter(win)
  else:
    discard