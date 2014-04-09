import os
import db_sqlite
import strutils

import ../WhiteStagEditor/utfstring
import types


type
  TDao = object
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

proc findById(self: ref TDao, id: int): ref TQuestion =
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



proc persist(self: ref TDao, q: ref TQuestion) =
  let questionId = self.conn.insertID(db_sqlite.sql"""INSERT INTO question (question, type, f, expl, tag) VALUES (?, ?, ?, ?, ?)""",
      q.problemStatement, q.getType(), q.f, q.explanation, q.tag)

  for answer in q.answers:
    discard self.conn.insertID(db_sqlite.sql"INSERT INTO answer(question_id, answer) VALUES (?, ?)", questionId, $answer)

when isMainModule:
  import unittest

  suite "View Test Suite":
    var dao: ref TDao
    setup:
      dao = createDao("test")

    teardown:
      dao.close()
      os.removeFile("test.db")

    test "persist":
      let q = new TQuestion
      q.problemStatement = utf"problemStatement"
      q.kind = TQuestionKind.qtypeControlledSkipping
      q.f = 3
      q.explanation = utf"explanation"
      q.tag = utf"tag"
      q.answers = @[utf"a", utf"b"]
      dao.persist(q)

      let q2 = dao.findById(1)
      check q2.problemStatement == "problemStatement"
      check q2.kind == TQuestionKind.qtypeControlledSkipping
      check q2.f == 3
      check q2.explanation == "explanation"
      check q2.tag == "tag"
      check q2.answers[0] == "a"
      check q2.answers[1] == "b"
      check q2.answers.len == 2

