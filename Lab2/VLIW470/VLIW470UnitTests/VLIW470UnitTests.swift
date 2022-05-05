//
//  VLIW470UnitTests.swift
//  VLIW470UnitTests
//
//  Created by Joel Rudsberg on 2022-05-05.
//

import XCTest

class VLIW470UnitTests: XCTestCase {

    func testScheduler() throws {
        FileIOController.folderPath = "/Users/joelrudsberg/Desktop/EPFL/adv-comp-arch/Advanced-Computer-Architecture/Lab2/VLIW470/VLIW470/resources"
        let program = try Parser().parseInstructions(fromFile: "test2.json")
        
        // Use example table
        let db = DependencyBuilder()
        let depTable = db.createTable(fromProgram: program)
        
        // Try schedule first using only bb0
        let s = Scheduler()
        var schedule = s.schedule(using: depTable)
        
        XCTAssertEqual(schedule.count, 2)
        XCTAssertEqual(schedule[0].ALU0, 0) // A
        XCTAssertEqual(schedule[0].ALU1, 1) // B
        XCTAssertTrue(schedule[0].Mult == nil && schedule[0].Mem == nil && schedule[0].Branch == nil)
        
    }
    
}
