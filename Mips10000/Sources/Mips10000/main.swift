import Foundation

// Format of arguments:
// 1. Path to folder having program files and where logging will be done
// 2. Program file name to run (must be in folder)
// 3. Log file name (will be saved in folder
let arguments = CommandLine.arguments

FileIOController.folderPath = arguments[1]
let config = RunConfig(
    programFile: arguments[2],
    logFile: arguments[3],
    runUpToCycle: nil
)

try App(config: config).run()

