//
//  main.swift
//  VLIW470
//
//  Created by Joel Rudsberg on 2022-05-02.
//

import Foundation

// Format of arguments:
// 1. Path to folder having program files and where logging will be done
// 2. Program file name to run including .json extension (must be in folder)
// 3. Log file name of simple VLIW including .json extension (will be saved in folder)
// 4. Log file name of pip VLIP including .json extension

let arguments = CommandLine.arguments
let folderPath = arguments[1]
FileIOController.folderPath = folderPath
let programFile = arguments[2]
let outputFileSimple = arguments[3]
let outputFilePip = arguments[4]

let config = Config(programFile: programFile, outputFileSimple: outputFileSimple, outputFilePip: outputFilePip)
try App(config: config).run()
