import ../WhiteStagEditor/utfstring
import ../WhiteStagEditor/panel

type
  TQuestionUi* = object of TObject
  TQuestionKind* = enum
    qtypeAnd
    qtypeOr
    qtypeContains
    qtypeControlledSkipping
    qtypeRandomSkipping
    qtypeTrueFalse
    qtypeMirror
  TQuestion* = object
    kind*: TQuestionKind
    problemStatement*: PUTFString
    answers*: seq[PUTFString]
    f*: int
    explanation*: PUTFString
    tag*: PUTFString

method fillEditorPanel*(self: ref TQuestionUi, panel: PPanel, question: ref TQuestion) = quit "to override!"
method createQuestionFromInput*(self: ref TQuestionUi): ref TQuestion = quit "to override!"

proc getType*(self: ref TQuestion): string =
    result = case self.kind:
    of qtypeAnd: "AND"
    of qtypeOr: "OR"
    of qtypeContains: "CONTAINS"
    of qtypeControlledSkipping: "CONTROLLED_SKIPPING"
    of qtypeRandomSkipping: "RANDOM_SKIPPING"
    of qtypeTrueFalse: "TRUE_FALSE"
    of qtypeMirror: "MIRROR"

proc parseType*(str: string): TQuestionKind =
    case str:
    of "AND": return qtypeAnd
    of "OR": return qtypeOr
    of "CONTAINS": return qtypeContains
    of "CONTROLLED_SKIPPING": return qtypeControlledSkipping
    of "RANDOM_SKIPPING": return qtypeRandomSkipping
    of "TRUE_FALSE": return qtypeTrueFalse
    of "MIRROR": return qtypeMirror