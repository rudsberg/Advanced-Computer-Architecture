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

struct DependencyTableEntry {
    let addr: Int
    // let id: String
    let instr: String
    let destReg: String?
    /// If the producer and the consumer are in the same basic block
    let localDep: [String]? // ID
    /// If the producer and consumer are in different basic blocks, and the consumer is in the loop body
    let interloopDep: [String]?
    let loopInvariantDep: [String]?
    let psotLoopDep: [String]?
}

let arguments = CommandLine.arguments
let folderPath = arguments[1]
FileIOController.folderPath = folderPath
let programFile = arguments[2]

// MARK: - Parse program
let program = try Parser().parseInstructions(fromFile: programFile)
print("======= Program =======")
program.forEach { print($0) }

// MARK: loop – Build dependency table
var depTable = [DependencyTableEntry]()
/// One before loopStart
let (loopStart, loopEnd) = program.reduce((0, 0), { acc, ins in
    if let instuction = ins.1 as? LoopInstruction {
        return (instuction.loopStart, ins.0)
    } else {
        return acc
    }
})
let bb0 = Array(program.prefix(loopStart))
let bb1 = Array(program.dropFirst(loopStart).prefix(loopEnd - loopStart + 1))
let bb2 = Array(program.dropFirst(loopEnd + 1))

/// Finds RAW dependencies
func findDependencies(in instructions: [(Int, Instruction)], for instruction: Instruction) -> [String] {
    guard let readRegs = instruction.readRegs else { return [] }
    
    // Simply those instructions with destReg that is same as readReg
    return instructions.filter { if let destReg = $0.1.destReg {
        return readRegs.contains(destReg)
    } else {
        return false
    }
    }.map { $0.0.toReg }
}

bb0.forEach { i in
    let entry = DependencyTableEntry(
        addr: i.0,
        instr: i.1.name,
        destReg: i.1.destReg,
        localDep: findDependencies(in: Array(bb0.prefix(i.0)), for: i.1),
        interloopDep: nil,
        loopInvariantDep: nil,
        psotLoopDep: nil
    )
    depTable.append(entry)
}

print("dep bb0", depTable)

// MARK: loop – Perform ASAP Scheduling
// Output: valid schedule table, i.e. what each execution unit should perform each stage for the 3 basic blocks. Addr | ALU0 | ALU1 | Mult | Mem | Branch
// Picks instruction in sequential order, checks the dependencies in table, and schedules the instruction in the earliest possible slot
// All instructions must obey: S(P) + λ(P) ≤ S(C) + II, if violation, recompute by increasing II

// MARK: loop – Register Allocation (alloc_b)
// Output: extended schedule table with register allocated
// Firstly, we allocate a fresh unique register to each instruction producing a new value. Result: all destination registers will be specified
// Secondly, links each operand to the register newly allocated in the previous phase. Result: all destination and operand registers set, but not mov instructions
// Thirdly, fix the interloop dependencies.

// MARK: loop – Print program

// TODO: same steps for loop.pip
// MARK: loop.pip – Prepare loop for execution

