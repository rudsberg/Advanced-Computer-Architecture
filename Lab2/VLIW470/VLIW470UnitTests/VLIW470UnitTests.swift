//
//  VLIW470UnitTests.swift
//  VLIW470UnitTests
//
//  Created by Joel Rudsberg on 2022-05-05.
//

import XCTest

class VLIW470UnitTests: XCTestCase {

    func testScheduler() throws {
        /*
         [
         0 - "mov LC, 10",
         1 - "mov x2, 0x1000",
         2 - "mov x3, 1",
         3 - "mov x4, 25",
         4 - "ld x5, 0(10)",
         5 - "loop 4",
         6 - "addi x6, x11, 1"
         ]
         */
        
        FileIOController.folderPath = "/Users/joelrudsberg/Desktop/EPFL/adv-comp-arch/Advanced-Computer-Architecture/Lab2/VLIW470/VLIW470/resources"
        let program = try Parser().parseInstructions(fromFile: "test2.json")
        
        // Use example table
        let db = DependencyBuilder()
        let depTable = db.createTable(fromProgram: program)
        
        // Try schedule first using only bb0
        let s = Scheduler()
        let schedule = s.schedule(using: depTable)
        
        XCTAssertEqual(schedule.count, 4)
        XCTAssertEqual(schedule[0].ALU0, 0) // A
        XCTAssertEqual(schedule[0].ALU1, 1) // B
        XCTAssertTrue(schedule[0].Mult == nil && schedule[0].Mem == nil && schedule[0].Branch == nil)
        
        XCTAssertEqual(schedule[1].ALU0, 2)
        XCTAssertEqual(schedule[1].ALU1, 3)
        XCTAssertTrue(schedule[1].Mult == nil && schedule[1].Mem == nil && schedule[1].Branch == nil)
        
        XCTAssertEqual(schedule[2].Mem, 4)
        XCTAssertEqual(schedule[2].Branch, 5)
        XCTAssertTrue(schedule[2].ALU0 == nil && schedule[2].ALU1 == nil && schedule[2].Mult == nil)
        
        XCTAssertEqual(schedule[3].ALU0, 6)
    }
    
}
