//
//  main.swift
//  VLIW470
//
//  Created by Joel Rudsberg on 2022-05-02.
//

import Foundation

// Format of arguments:
// 1. Path to folder having program files and where logging will be done
// 2. Program file name to run (must be in folder)
// 3. Log file name (will be saved in folder)

let arguments = CommandLine.arguments
let folderPath = arguments[1]
FileIOController.folderPath = folderPath
let programFile = arguments[2]
let outputFile = arguments[3]

let config = Config(programFile: programFile, outputFile: outputFile)
try App(config: config).run()
