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
    let postLoopDep: [String]?
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

/// Finds dependencies
func findDependencies(in instructions: [(Int, Instruction)], for instruction: Instruction) -> [String] {
    let RAW = instructions.filter {
        guard let readRegs = instruction.readRegs, let destReg = $0.1.destReg else {
            return false
        }
        return readRegs.contains(destReg)
    }
    return RAW.map { "\($0.0)" }
}

bb0.forEach { i in
    let entry = DependencyTableEntry(
        addr: i.0,
        instr: i.1.name,
        destReg: i.1.destReg,
        localDep: findDependencies(in: Array(bb0.prefix(i.0)), for: i.1),
        interloopDep: nil,
        loopInvariantDep: nil,
        postLoopDep: nil
    )
    depTable.append(entry)
}

bb1.forEach { i in
    // If a register is assigned prior to the loop and only read within the loop, it is a loop invariant
    // Thus: take instructions assigned to before and not written to in loop
    let consideredLoopInvInstructions = bb0.producingInstructions.filter{ assignedI in
        // Only read in loop
        let destReg = assignedI.1.destReg!
        return !bb1.contains(where: { $0.1.destReg == destReg })
    }
    // An operand of instruction A has an interloop dependency if it is either produced within the loop body,
    // after A in sequential program order, or before the loop, in BB0 (or both).
    // Thus: take instructions after i and in bb0
    var consideredInterLoopInstructions = bb1.dropFirst(i.0 - loopStart).producingInstructions + bb0.producingInstructions
    consideredInterLoopInstructions = consideredInterLoopInstructions.filter { i in !consideredLoopInvInstructions.contains(where: { $0.0 == i.0 }) }
    let entry = DependencyTableEntry(
        addr: i.0,
        instr: i.1.name,
        destReg: i.1.destReg,
        // Search dep those before curr instr in same block
        localDep: findDependencies(in: Array(bb1.prefix(i.0 - loopStart)), for: i.1),
        interloopDep: findDependencies(in: consideredInterLoopInstructions, for: i.1),
        loopInvariantDep: findDependencies(in: consideredLoopInvInstructions, for: i.1),
        postLoopDep: nil
    )
    depTable.append(entry)
}

bb2.forEach { i in
    let entry = DependencyTableEntry(
        addr: i.0,
        instr: i.1.name,
        destReg: i.1.destReg,
        localDep: findDependencies(in: Array(bb2.prefix(i.0 - loopEnd - 1)), for: i.1),
        interloopDep: nil,
        loopInvariantDep: nil,
        // Producer in bb1 and consumer in bb2
        postLoopDep: findDependencies(in: bb1, for: i.1)
    )
    depTable.append(entry)
}

print("")
depTable.forEach({ print($0) })

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

