//
//  VLIW470UnitTests.swift
//  VLIW470UnitTests
//
//  Created by Joel Rudsberg on 2022-05-05.
//

import XCTest

class VLIW470UnitTests: XCTestCase {
    private let folderPath = "/Users/joelrudsberg/Desktop/EPFL/adv-comp-arch/Advanced-Computer-Architecture/Lab2/VLIW470/VLIW470/resources"

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
        
        let s = Scheduler(depTable: depTable)
        let schedule = s.schedule_loop()
        
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
        let depTable = DependencyBuilder().createTable(fromProgram: program)
        
        let s = Scheduler(depTable: depTable)
        let schedule = s.schedule_loop()
        
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
    
    func testScheduler3() throws {
        /*
         [
             "mov LC, 100",
             "mov x2, 5",
             "mulu x2, x2, x2",
             "add x2, x2, x2",
             "loop 3",
             "st x2, 0x1000(x0)"
         ]
         */
        
        let program = try createProgram(fromFile: "test.json")
        let db = DependencyBuilder()
        let depTable = db.createTable(fromProgram: program)
        
        let s = Scheduler(depTable: depTable)
        let schedule = s.schedule_loop()
        
        XCTAssertEqual(schedule.count, 6)
        XCTAssertEqual(schedule[0].ALU0, 0)
        XCTAssertEqual(schedule[0].ALU1, 1)
        XCTAssertTrue(schedule[0].Mult == nil && schedule[0].Mem == nil && schedule[0].Branch == nil)
        
        XCTAssertEqual(schedule[1].Mult, 2)
        XCTAssertTrue(schedule[1].ALU0 == nil && schedule[1].ALU1 == nil && schedule[1].Mem == nil && schedule[1].Branch == nil)
        
        executionUnitsEmpty(bundle: schedule[2])
        
        executionUnitsEmpty(bundle: schedule[3])
        
        XCTAssertEqual(schedule[4].ALU0, 3)
        XCTAssertEqual(schedule[4].Branch, 4)
        
        XCTAssertEqual(schedule[5].Mem, 5)
    }
    
    func testScheduler4() throws {
        /*
         [
         "mov x1, 10",
         "mulu x2, x1, x2",
         "loop 1",
         "addi x3, x4, 1"
         ]
         */
        // Should create a loop of size 3 due to the interloop dep
        
        let program = try createProgram(fromFile: "test3.json")
        let db = DependencyBuilder()
        let depTable = db.createTable(fromProgram: program)
        
        let s = Scheduler(depTable: depTable)
        let schedule = s.schedule_loop()
        
        // TODO: 
        XCTAssertEqual(schedule.filter { $0.block == 1 }.count, 3)
    }
    
    func testSchedulerPip1() throws {
        let program = try createProgram(fromFile: "handout.json")
        let db = DependencyBuilder()
        let depTable = db.createTable(fromProgram: program)
        
        let s = Scheduler(depTable: depTable)
        let schedule = s.schedule_loop_pip()
    }
    
    func testAlloc_b() throws {
        let program = try createProgram(fromFile: "handout.json")
        let db = DependencyBuilder()
        let depTable = db.createTable(fromProgram: program)
        let s = Scheduler(depTable: depTable)
        let schedule = s.schedule_loop()
        
        let res = RegisterAllocator(depTable: depTable, schedule: schedule).alloc_b()
        let t = res.table
        
    }
    
    func testAlloc_r() throws {
        let program = try createProgram(fromFile: "handout.json")
        let db = DependencyBuilder()
        let depTable = db.createTable(fromProgram: program)
        let s = Scheduler(depTable: depTable)
        let schedule = s.schedule_loop_pip()
        
        let res = RegisterAllocator(depTable: depTable, schedule: schedule).alloc_r()
        let t = res.table
        
        XCTAssertEqual(t[0].ALU1.instr?.addr.toChar, "B")
        XCTAssertEqual(t[0].ALU1.instr?.destReg?.regToNum, 32+1+0)
        
        XCTAssertEqual(t[1].ALU0.instr?.addr.toChar, "C")
        XCTAssertEqual(t[1].ALU0.instr?.destReg?.regToNum, 41+1+0)
        XCTAssertEqual(t[1].ALU1.instr?.addr.toChar, "D")
        XCTAssertEqual(t[1].ALU1.instr?.destReg?.regToNum, 1)
        
        XCTAssertEqual(t[2].ALU0.instr?.addr.toChar, "I")
        XCTAssertEqual(t[2].ALU0.instr?.destReg?.regToNum, 32)
        XCTAssertEqual(t[2].ALU0.instr?.readRegs?[0].regToNum, 32+1)
        XCTAssertEqual(t[2].Mem.instr?.addr.toChar, "E")
        XCTAssertEqual(t[2].Mem.instr?.destReg?.regToNum, 35)
        XCTAssertEqual(t[2].Mem.instr?.readRegs?[0].regToNum, 32+1)
        
        XCTAssertEqual(t[3].Mult.instr?.addr.toChar, "F")
        XCTAssertEqual(t[3].Mult.instr?.destReg?.regToNum, 38)
        XCTAssertEqual(t[3].Mult.instr?.readRegs?[0].regToNum, 35+0+0)
        XCTAssertEqual(t[3].Mult.instr?.readRegs?[1].regToNum, 1)
        
        XCTAssertEqual(t[4].Mult.instr?.addr.toChar, "G")
        XCTAssertEqual(t[4].Mult.instr?.destReg?.regToNum, 41)
        XCTAssertEqual(t[4].Mult.instr?.readRegs?[0].regToNum, 41+1+0)
        XCTAssertEqual(t[4].Mult.instr?.readRegs?[1].regToNum, 35+0+0)
        
        XCTAssertEqual(t[6].Mem.instr?.addr.toChar, "H")
//        XCTAssertEqual(t[6].Mem.instr?.readRegs?[0].regToNum, 38+0+1)
        XCTAssertEqual(t[6].Mem.instr?.readRegs?[1].regToNum, 32+1+1)
        
//        XCTAssertEqual(t[6].Mem.instr?.readRegs?[0].regToNum, 38+0+1)  // TODO: after store reg has been assigned
    }
    
    func testVLIWSimple() throws {
        FileIOController.folderPath = folderPath
        let config = Config(programFile: "handout.json", outputFile: "handout-loop.json")
        let app = App(config: config)
        try app.run()
        
        let output = try FileIOController.shared.read([[String]].self, documentName: "handout-loop.json")
        let oracle = try FileIOController.shared.read([[String]].self, documentName: "vliwsimple.json")
        
        XCTAssertEqual(output.count, oracle.count)
        zip(output, oracle).forEach { (r1, r2) in
            XCTAssertEqual(r1, r2.map { $0.trimmingCharacters(in: .whitespaces) })
        }
    }
    
    private func executionUnitsEmpty(bundle: ScheduleRow) {
        XCTAssertTrue(bundle.ALU0 == nil && bundle.ALU1 == nil && bundle.Mult == nil && bundle.Mem == nil && bundle.Branch == nil)
    }
    
    private func createProgram(fromFile file: String) throws -> Program {
        FileIOController.folderPath = folderPath
        let program = try Parser().parseInstructions(fromFile: file)
        return program
    }
    
}
