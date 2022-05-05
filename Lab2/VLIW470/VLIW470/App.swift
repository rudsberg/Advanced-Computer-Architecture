//
//  App.swift
//  VLIW470
//
//  Created by Joel Rudsberg on 2022-05-04.
//

import Foundation

struct Config {
    let programFile: String
}

struct App {
    let config: Config
    
    func run() throws {
        // MARK: - Parse program
        let program = try Parser().parseInstructions(fromFile: config.programFile)
        print("======= Program =======")
        program.forEach { print($0) }

        // MARK: loop – Build dependency table
        let depTable = DependencyBuilder().createTable(fromProgram: program)

        // MARK: loop – Perform ASAP Scheduling
//        let schedule = Scheduler().schedule(using: depTable)

        // MARK: loop – Register Allocation (alloc_b)
        // Output: extended schedule table with register allocated
        // Firstly, we allocate a fresh unique register to each instruction producing a new value. Result: all destination registers will be specified
        // Secondly, links each operand to the register newly allocated in the previous phase. Result: all destination and operand registers set, but not mov instructions
        // Thirdly, fix the interloop dependencies.

        // MARK: loop – Print program

        // TODO: same steps for loop.pip
        // MARK: loop.pip – Prepare loop for execution

    }
}
