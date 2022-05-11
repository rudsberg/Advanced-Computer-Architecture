//
//  App.swift
//  VLIW470
//
//  Created by Joel Rudsberg on 2022-05-04.
//

import Foundation

struct Config {
    let programFile: String
    let outputFileSimple: String
    let outputFilePip: String
}

struct Result {
    let simpleSchedule: Schedule
    let pipSchedule: Schedule
}

struct App {
    let config: Config
    
    @discardableResult
    func run() throws -> Result {
        // Parse program
        let program = try Parser().parseInstructions(fromFile: config.programFile)

        // Build dependency table
        let depTable = DependencyBuilder().createTable(fromProgram: program)

        // Perform ASAP Scheduling
        let scheduler = Scheduler(depTable: depTable)
        let scheduleSimple = scheduler.schedule_loop()
        let schedulePip = scheduler.schedule_loop_pip()
        
        // Perform Register allocation
        let allocatedTableSimple = RegisterAllocator(depTable: depTable, schedule: scheduleSimple).alloc_b()
        var allocatedTablePip = RegisterAllocator(depTable: depTable, schedule: schedulePip).alloc_r()
        
        // Prepare loop for pip
        allocatedTablePip = LoopPreparer(schedule: schedulePip, allocTable: allocatedTablePip).prepare()
        
        // Print the results
        let logger = Logger()
        try logger.log(allocTable: allocatedTableSimple, documentName: config.outputFileSimple)
        try logger.log(allocTable: allocatedTablePip, documentName: config.outputFilePip)
        
        return .init(simpleSchedule: scheduleSimple, pipSchedule: schedulePip)
    }
}
