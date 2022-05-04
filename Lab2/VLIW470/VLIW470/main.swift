//
//  main.swift
//  VLIW470
//
//  Created by Joel Rudsberg on 2022-05-02.
//

import Foundation
import Algorithms

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
        phase: 0,
        addr: i.0,
        instr: i.1,
        destReg: i.1.destReg,
        localDep: findDependencies(in: Array(bb0.prefix(i.0)), for: i.1),
        interloopDep: [],
        loopInvariantDep: [],
        postLoopDep: []
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
        phase: 1,
        addr: i.0,
        instr: i.1,
        destReg: i.1.destReg,
        // Search dep those before curr instr in same block
        localDep: findDependencies(in: Array(bb1.prefix(i.0 - loopStart)), for: i.1),
        interloopDep: findDependencies(in: consideredInterLoopInstructions, for: i.1),
        loopInvariantDep: findDependencies(in: consideredLoopInvInstructions, for: i.1),
        postLoopDep: []
    )
    depTable.append(entry)
}

bb2.forEach { i in
    let entry = DependencyTableEntry(
        phase: 2,
        addr: i.0,
        instr: i.1,
        destReg: i.1.destReg,
        localDep: findDependencies(in: Array(bb2.prefix(i.0 - loopEnd - 1)), for: i.1),
        interloopDep: [],
        loopInvariantDep: [],
        // Producer in bb1 and consumer in bb2
        postLoopDep: findDependencies(in: bb1, for: i.1)
    )
    depTable.append(entry)
}

print("======= Dependency Table =======")
depTable.forEach({ print($0) })

// MARK: loop – Perform ASAP Scheduling
/// Max value of the set of already scheduled instructions + their latency
func earliestScheduledStage(for entry: DependencyTableEntry, in schedule: [ScheduleRow]) -> Int {
    // Find all dependencies (as addresses) that are already scheduled
    let allDeps = [entry.localDep + entry.interloopDep + entry.loopInvariantDep + entry.postLoopDep]
        .flatMap { $0 }
        .map { Int($0)! }

    // Filter out states that have match dependency
    let earliestPossibleAddress = schedule
        .filter { allDeps.contains($0.ALU0 ?? -1) || allDeps.contains($0.ALU1 ?? -1) || allDeps.contains($0.Mult ?? -1) || allDeps.contains($0.Mem ?? -1) || allDeps.contains($0.Branch ?? -1) }
        .map {
            $0.addr + (allDeps.contains($0.Mult ?? -1) ? 3 : 1) // MUL latency of 3, all else 1
        }
        .max()
    
    return earliestPossibleAddress ?? 0
}

/// Starts trying to add entry to schedule at index, will increase schedule size if needed, and add earliest possible to the right unit. Moves down if occupied
func addToSchedule(_ entry: DependencyTableEntry, atEarliest index: Int, in schedule: [ScheduleRow]) -> [ScheduleRow] {
    var schedule = schedule
    var i = index
    
    while (true) {
        // If exceed schedule, append empty row
        if (i >= schedule.count) {
            schedule.append(.init(addr: i))
        }
        
        if let updatedRow = update(schedule[i], ifCanBeHandled: entry) {
            schedule[i] = updatedRow
            return schedule
        } else {
            i += 1
        }
        
        // TODO: remove for submission
        if (i > 10000) { fatalError("infinte loop...") }
    }

    return schedule
}

func update(_ row: ScheduleRow, ifCanBeHandled entry: DependencyTableEntry) -> ScheduleRow? {
    var row = row
    switch entry.instr.execUnit {
    case .ALU:
        if row.ALU0 == nil {
            row.ALU0 = entry.addr
            return row
        } else if row.ALU1 == nil {
            row.ALU1 = entry.addr
            return row
        }
    case .Mult:
        if row.Mult == nil {
            row.Mult = entry.addr
            return row
        }
    case .Mem:
        if row.Mem == nil {
            row.Mem = entry.addr
            return row
        }
    case .Branch:
        if row.Branch == nil {
            row.Branch = entry.addr
            return row
        }
    }
    return nil
}

func updateSchedule(entries: [DependencyTableEntry], schedule: [ScheduleRow]) -> [ScheduleRow] {
    var schedule = schedule
    entries.forEach { entry in
        let stage = earliestScheduledStage(for: entry, in: schedule)
        schedule.append(contentsOf: addToSchedule(entry, atEarliest: stage, in: schedule))
    }
    return schedule
}

private func equationHolds(forLoopInstructions schedule: [ScheduleRow], II: Int) -> Bool {
    let loopInstructions = schedule
    // Group by ALU types
    let iALU0 = loopInstructions.filter { $0.ALU0 != nil }.map { ($0.addr, ExecutionUnit.ALU) }
    let iALU1 = loopInstructions.filter { $0.ALU1 != nil }.map { ($0.addr, ExecutionUnit.ALU) }
    let Mult = loopInstructions.filter { $0.Mult != nil }.map { ($0.addr, ExecutionUnit.Mult) }
    let Mem = loopInstructions.filter { $0.Mem != nil }.map { ($0.addr, ExecutionUnit.Mem) }
    let Branch = loopInstructions.filter { $0.Branch != nil }.map { ($0.addr, ExecutionUnit.Branch) }
    
    return [iALU0, iALU1, Mult, Mem, Branch].allSatisfy { equationHolds(for: $0, II: II) }
}

private func equationHolds(for entries: [(Address, ExecutionUnit)], II: Int) -> Bool {
    guard entries.count > 1 else { return true }
    
    func S(_ entry: (Address, ExecutionUnit)) -> Int {
        entry.0
    }
    
    func λ(_ entry: (Address, ExecutionUnit)) -> Int {
        entry.1 == .Mult ? 3 : 1
    }
    
    return entries.combinations(ofCount: 2).allSatisfy { combo in
        guard combo.count > 1 else { return true }
        // S(P) + λ(P) ≤ S(C) + II
        let P = combo[0]
        let C = combo[1]
        return S(P) + λ(P) <= S(C) + II
    }
}

// Output: valid schedule table, i.e. what each execution unit should perform each stage for the 3 basic blocks. Addr | ALU0 | ALU1 | Mult | Mem | Branch
// Picks instruction in sequential order, checks the dependencies in table, and schedules the instruction in the earliest possible slot
// All instructions must obey: S(P) + λ(P) ≤ S(C) + II, if violation, recompute by increasing II
typealias InLoop = Bool
var schedule = [(InLoop, ScheduleRow)]()
var II = 1
repeat {
    // Update schedule for each phase
    for phase in [0, 1, 2] {
        let newSchedule = updateSchedule(
            entries: depTable.filter { $0.phase == phase },
            schedule: schedule.map { $0.1 }
        ).map { (phase == 1, $0) }
        
        schedule.append(contentsOf: newSchedule)
    }
        
    // Check if equation holds for all interloop instructions. If not, increase II and try again
    let loopInstructions = schedule.filter { $0.0 }.map { $0.1 }
    if equationHolds(forLoopInstructions: loopInstructions, II: II) {
        print("Valid schedule for \(II) ✅")
        break
    } else {
        print("II broken for \(II)")
        schedule.removeAll()
        II += 1
    }
    
    // TODO: remove for submission
    if (II > 1000) { fatalError("Infinite loop") }
} while (true)

print("\nSchedule:")
schedule.forEach({ print($0) })

// MARK: loop – Register Allocation (alloc_b)
// Output: extended schedule table with register allocated
// Firstly, we allocate a fresh unique register to each instruction producing a new value. Result: all destination registers will be specified
// Secondly, links each operand to the register newly allocated in the previous phase. Result: all destination and operand registers set, but not mov instructions
// Thirdly, fix the interloop dependencies.

// MARK: loop – Print program

// TODO: same steps for loop.pip
// MARK: loop.pip – Prepare loop for execution

