import os
import strutils
import osproc
import terminal
import streams

var compiledModules: seq[string] = @[]

var commands: seq[string] = @[]

type
  TUnitTest = object
    name: string
    succes: bool
    moduleName: string

  TTestModule = object
    name: string
    tests: seq[TUnitTest]
    successfulTestCount: int
    failedTestCount: int

proc execProcesses(exeNames: openarray[string]): seq[TTestModule] =
  var tests: seq[TTestModule] = @[]
  for exeName in exeNames:
    echo exeName & " ..."
    var p = startCmd(exeName)
    var outp = outputStream(p)
    var line = newStringOfCap(120).TaintedString
    var testModule = TTestModule(name: exeName, tests: @[])
    while true:
      if outp.readLine(line):
        if "[OK]" == line[0..3]:
          let testName = line[5..high(line)]
          let result = TUnitTest(succes: true, name: testName, moduleName: exeName)
          testModule.tests.add(result)
          inc testModule.successfulTestCount
        elif "[FAILED]" == line[0..7]:
          let testName = line[9..high(line)]
          let result = TUnitTest(succes: false, name: testName, moduleName: exeName)
          testModule.tests.add(result)
          inc testModule.failedTestCount
      elif not running(p): break
    tests.add(testModule)
    close(p)
  return tests

for fullName in walkDirRec("."):
  if fullName.endsWith(".nim") == false:
    continue
  let moduleName = fullName[0..fullName.len-5]
  var file: TFile
  discard Open(file, fullName)
  let content = file.readAll()
  let searchFor = "import " & "unittest"
  if content.find(searchFor) == -1:
    continue
  let exeName = moduleName & ".exe"
  commands.add(exeName)
  if existsFile(exeName):
    echo "SKIP COMPILING " & moduleName
    compiledModules.add(moduleName)
    continue
  if execCmd("nimrod c --verbosity:0 " & moduleName) != 0:
    quit 1
  compiledModules.add(moduleName)

let tests = execProcesses(commands)
var allTests = 0
var allSuccessfulTestCount = 0
var failedTests: seq[TUnitTest] = @[]
for test in tests:
  inc(allTests, test.tests.len)
  inc(allSuccessfulTestCount, test.successfulTestCount)

  setForegroundColor(fgWhite)
  stdout.write(test.name)
  stdout.write("[")
  if test.successfulTestCount == test.tests.len:
    setForegroundColor(fgGreen)
  else:
    setForegroundColor(fgRed)
  stdout.write($test.successfulTestCount)

  resetAttributes()
  setForegroundColor(fgWhite)
  stdout.write("/")
  stdout.write($test.tests.len)
  stdout.write("]\n")

  for unitTest in test.tests:
    setForegroundColor(fgWhite)
    stdout.write("\t[")
    if unitTest.succes:
      setForegroundColor(fgGreen)
      stdout.write("OK")
    else:
      setForegroundColor(fgRed)
      stdout.write("FAILED")
      failedTests.add(unitTest)
    setForegroundColor(fgWhite)
    stdout.write("] ")
    stdout.write(unitTest.name & "\n")
  
setForegroundColor(fgWhite)
stdout.write("==========================================\nSummary ")
stdout.write("[")
if allSuccessfulTestCount == allTests:
  setForegroundColor(fgGreen)
else:
  setForegroundColor(fgRed)
stdout.write($allSuccessfulTestCount)

resetAttributes()
setForegroundColor(fgWhite)
stdout.write("/")
stdout.write($allTests)
stdout.write("]\n")
if failedTests.len > 0:
  stdout.write("Failed tests: \n")
  for failedTest in failedTests:
    stdout.write(failedTest.moduleName & " -> " & failedTest.name & "\n")

for moduleName in compiledModules:
  let exeName = moduleName & ".exe"
  removeFile(exeName)

resetAttributes()
