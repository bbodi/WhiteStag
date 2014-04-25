import os
import db_sqlite
import strutils

import ../WhiteStagEditor/utfstring
import ../WhiteStagEditor/option
import types


type
  TDao* = object
    conn: TDbConn

proc initDb(self: ref TDao) =
  var sql = db_sqlite.sql"""CREATE TABLE QUESTION(
          ID         INTEGER   PRIMARY KEY  AUTOINCREMENT, 
          question   TEXT      NOT NULL, 
          TYPE       CHAR(50)  NOT NULL,
          F          INTEGER   NOT NULL,
          TAG        CHAR(100),
          expl       TEXT      )"""

  db_sqlite.exec(self.conn, sql)

  sql = db_sqlite.sql"""CREATE TABLE ANSWER(
          ID            INTEGER     PRIMARY KEY AUTOINCREMENT, 
          QUESTION_ID   TEXT    NOT NULL, 
          ANSWER        TEXT    NOT NULL)"""

  db_sqlite.exec(self.conn, sql)


proc createDao*(dbName: string): ref TDao =
  result = new TDao
  let fileName = dbName & ".db"
  let newdb = not existsFile(fileName)
  result.conn = db_sqlite.Open(fileName, "", "", "")
  if newdb:
    result.initDb()

proc close*(self: ref TDao) =
  self.conn.close()

proc findQuestionById*(self: ref TDao, id: int64): ref TQuestion =
  let row = self.conn.getRow(db_sqlite.sql"SELECT question, type, f, tag, expl FROM question WHERE id = ?", id)
  result = new TQuestion
  result.problemStatement = newString(row[0])
  result.kind = parseType(row[1])
  result.f = parseInt(row[2])
  result.tag = newString(row[3])
  result.explanation = newString(row[4])

  result.answers = @[]
  for answerRow in self.conn.fastRows(db_sqlite.sql"SELECT answer FROM answer WHERE question_id = ?", id):
    result.answers.add(newString(answerRow[0]))
  result.id = some(id)

proc findAllQuestion*(self: ref TDao): seq[ref TQuestion] =
  result = @[]
  for row in self.conn.FastRows(db_sqlite.sql"SELECT id, question, type, f, tag, expl FROM question"):
    echo repr(row)
    let q = new TQuestion
    echo "a"
    echo repr(parseInt(row[0]))
    echo "b"
    echo repr(some[int](1))
    echo "c"
    q.id = some(cast[int64](parseInt(row[0])))
    echo repr(q)
    q.problemStatement = newString(row[1])
    q.kind = parseType(row[2])
    q.f = parseInt(row[3])
    q.tag = newString(row[4])
    q.explanation = newString(row[5])


    q.answers = @[]
    for answerRow in self.conn.fastRows(db_sqlite.sql"SELECT answer FROM answer WHERE question_id = ?", q.id.data):
      q.answers.add(newString(answerRow[0]))
    result.add(q)

proc insertAnswers(self: ref TDao, q: ref TQuestion) =
  let questionId = q.id.expect("Tried to persist a detached object!")
  for answer in q.answers:
    discard self.conn.insertID(db_sqlite.sql"INSERT INTO answer(question_id, answer) VALUES (?, ?)", questionId, $answer)

proc insertQuestion*(self: ref TDao, q: ref TQuestion) =
  let questionId = self.conn.insertID(db_sqlite.sql"""INSERT INTO question (question, type, f, expl, tag) VALUES (?, ?, ?, ?, ?)""",
      q.problemStatement, q.getType(), q.f, q.explanation, q.tag)
  q.id = some(cast[int64](questionId))
  self.insertAnswers(q)

proc updateQuestion*(self: ref TDao, q: ref TQuestion) =
  let questionId = q.id.expect("Tried to persist a detached object!")
  self.conn.exec(db_sqlite.sql"""UPDATE question SET question=?, type=?, f=?, expl=?, tag=? WHERE id=?""",
      q.problemStatement, q.getType(), q.f, q.explanation, q.tag, questionId)
  

  self.conn.exec(db_sqlite.sql"DELETE FROM answer WHERE question_id=?", questionId)
  self.insertAnswers(q)

when isMainModule:
  import unittest

  suite "View Test Suite":
    var dao: ref TDao
    setup:
      dao = createDao("test")

    teardown:
      dao.close()
      os.removeFile("test.db")

    test "insert":
      let q = new TQuestion
      q.problemStatement = utf"problemStatement"
      q.kind = TQuestionKind.qtypeControlledSkipping
      q.f = 3
      q.explanation = utf"explanation"
      q.tag = utf"tag"
      q.answers = @[utf"a", utf"b"]
      dao.insertQuestion(q)
      check q.id.equals(1)

      let q2 = dao.findQuestionById(1)
      check q2.id.isSome
      check q2.problemStatement == "problemStatement"
      check q2.kind == TQuestionKind.qtypeControlledSkipping
      check q2.f == 3
      check q2.explanation == "explanation"
      check q2.tag == "tag"
      check q2.answers == @[utf"a", utf"b"]

    test "update":
      let q = new TQuestion
      q.problemStatement = utf"problemStatement"
      q.kind = TQuestionKind.qtypeControlledSkipping
      q.f = 3
      q.explanation = utf"explanation"
      q.tag = utf"tag"
      q.answers = @[utf"a", utf"b"]
      dao.insertQuestion(q)

      q.problemStatement = utf"problemStatement2"
      q.kind = TQuestionKind.qtypeAnd
      q.f = 4
      q.explanation = utf"explanation2"
      q.tag = utf"tag2"
      q.answers = @[utf"a", utf"c", utf"d"]
      dao.updateQuestion(q)
      let q2 = dao.findQuestionById(1)
      check q2.problemStatement == "problemStatement2"
      check q2.kind == TQuestionKind.qtypeAnd
      check q2.f == 4
      check q2.explanation == "explanation2"
      check q2.tag == "tag2"
      check q2.answers == @[utf"a", utf"c", utf"d"]

    test "find all":
      let q = new TQuestion
      q.problemStatement = utf"problemStatement"
      q.kind = TQuestionKind.qtypeControlledSkipping
      q.f = 3
      q.explanation = utf"explanation"
      q.tag = utf"tag"
      q.answers = @[utf"a", utf"b"]
      dao.insertQuestion(q)
      q.id = none[int64]()
      dao.insertQuestion(q)
      q.id = none[int64]()
      dao.insertQuestion(q)

      let qs = dao.findAllQuestion()
      check qs.len == 3
      check qs.map(proc(q: ref TQuestion): int = q.id.data) == @[1, 2, 3]