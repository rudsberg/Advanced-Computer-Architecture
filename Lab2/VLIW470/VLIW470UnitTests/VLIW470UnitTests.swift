//
//  VLIW470UnitTests.swift
//  VLIW470UnitTests
//
//  Created by Joel Rudsberg on 2022-05-05.
//

import XCTest

class VLIW470UnitTests: XCTestCase {

    func testScheduler1() throws {
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
        
        let program = try createProgram(fromFile: "test2.json")
        let db = DependencyBuilder()
        let depTable = db.createTable(fromProgram: program)
        
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
    
    func testScheduler2() throws {
        let program = try createProgram(fromFile: "handout.json")
        let db = DependencyBuilder()
        let depTable = db.createTable(fromProgram: program)
        
        let s = Scheduler()
        let schedule = s.schedule(using: depTable)
        
        XCTAssertEqual(schedule.count, 8)
        XCTAssertEqual(schedule[0].ALU0.toChar, "A") // A
        XCTAssertEqual(schedule[0].ALU1.toChar, "B") // B
        XCTAssertTrue(schedule[0].Mult == nil && schedule[0].Mem == nil && schedule[0].Branch == nil)
        
        XCTAssertEqual(schedule[1].ALU0.toChar, "C")
        XCTAssertEqual(schedule[1].ALU1.toChar, "D")
        XCTAssertTrue(schedule[1].Mult == nil && schedule[1].Mem == nil && schedule[1].Branch == nil)
        
        XCTAssertEqual(schedule[2].ALU0.toChar, "I")
        XCTAssertEqual(schedule[2].Mem.toChar, "E")
        
        XCTAssertEqual(schedule[3].Mult.toChar, "F")
        
        XCTAssertEqual(schedule[4].Mult.toChar, "G")
        
        XCTAssertTrue(schedule[5].ALU0 == nil && schedule[5].ALU1 == nil && schedule[5].Mult == nil && schedule[5].Mem == nil && schedule[5].Branch == nil)

        XCTAssertEqual(schedule[6].Mem.toChar, "H")
        XCTAssertEqual(schedule[6].Branch.toChar, "J")
        
        XCTAssertEqual(schedule[7].Mem.toChar, "K")
    }
    
    private func createProgram(fromFile file: String) throws -> [(Int, Instruction)] {
        FileIOController.folderPath = "/Users/joelrudsberg/Desktop/EPFL/adv-comp-arch/Advanced-Computer-Architecture/Lab2/VLIW470/VLIW470/resources"
        let program = try Parser().parseInstructions(fromFile: file)
        return program
    }
    
}
