//
//  main.swift
//  VLIW470
//
//  Created by Joel Rudsberg on 2022-05-02.
//

import Foundation

// Sample input:
/*
 [
 "mov LC, 10",
 "mov x2, 0x1000",
 "mov x3, 1",
 "mov x4, 25",
 "ld x5, 0(x2)",
 "mulu x6, x5, x4",
 "mulu x3, x3, x5",
 "st x6, 0(x2)",
 "addi x2, x2, 1",
 "loop 4",
 "st x3, 0(x2)"
 ]
 */

// Output for loop:
/*
 [
 [" mov LC, 10", " mov x1, 4096", " nop", " nop", " nop"],
 [" mov x2, 1", " mov x3, 25", " nop", " nop", " nop"],
 [" addi x4, x1, 1", " nop", " nop", " ld x5, 0(x1)", " nop"],
 [" nop", " nop", " mulu x6, x5, x3", " nop", " nop"],
 [" nop", " nop", " mulu x7, x2, x5", " nop", " nop"],
 [" nop", " nop", " nop", " nop", " nop"],
 [" mov x1, x4", " nop", " nop", " st x6, 0(x1)", " nop"],
 [" mov x2, x7", " nop", " nop", " nop", " loop 2"],
 [" nop", " nop", " nop", " st x7, 0(x4)", " nop"]
 ]
 */

let arguments = CommandLine.arguments
let folderPath = arguments[1]
FileIOController.folderPath = folderPath
let programFile = arguments[2]

let config = Config(programFile: programFile)
try App(config: config).run()
