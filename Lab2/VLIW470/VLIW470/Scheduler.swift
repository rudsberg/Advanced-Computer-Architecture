//
//  Scheduling.swift
//  VLIW470
//
//  Created by Joel Rudsberg on 2022-05-04.
//

import Foundation
import Algorithms

struct Scheduler {
    func schedule(using depTable: [DependencyTableEntry]) -> [ScheduleRow] {
        // Output: valid schedule table, i.e. what each execution unit should perform each stage for the 3 basic blocks. Addr | ALU0 | ALU1 | Mult | Mem | Branch
        // Picks instruction in sequential order, checks the dependencies in table, and schedules the instruction in the earliest possible slot
        // All instructions must obey: S(P) + λ(P) ≤ S(C) + II, if violation, recompute by increasing II
        var schedule = [ScheduleRow]()
        // Could be calculated but it will sort itself out by violating the equation
        var II = 1
        repeat {
            schedule = createSchedule(entries: depTable)
                
            // Check if equation holds for all interloop instructions. If not, increase II and try again
            let loopInstructions = schedule.filter { $0.block == 1 }
            if equationHolds(forLoopInstructions: loopInstructions, II: II) {
                print("Valid schedule for II=\(II) ✅")
                break
            } else {
                print("II broken for \(II)")
                schedule.removeAll()
                // TODO: add bundle in loop body...
                II += 1
            }
            
            // TODO: remove for submission
            if (II > 1000) { fatalError("Infinite loop") }
        } while (true)
        
        print("\n======= Schedule =======")
        schedule.forEach({ print($0) })
         
        return schedule.map { $0 }
    }
    
    private func createSchedule(entries: [DependencyTableEntry]) -> [ScheduleRow] {
        var schedule = [ScheduleRow]()
        entries.forEach { entry in
            let stage = earliestScheduledStage(for: entry, in: schedule)
            schedule = addToSchedule(entry, atEarliest: stage, in: schedule)
        }
        return schedule
    }
    
    /// Finds earliest possible bundle to schedule entry within it's block (bb0/1/2). Does not execution units if they are busy or not.
    private func earliestScheduledStage(for entry: DependencyTableEntry, in schedule: [ScheduleRow]) -> Int {
        if entry.instr.execUnit == .Branch {
            return lastAddrInBlock(block: 1, in: schedule)
        }
        
        // Find all dependencies (as addresses) that are already scheduled
        let allDeps = [entry.localDep + entry.interloopDep + entry.loopInvariantDep + entry.postLoopDep]
            .flatMap { $0 }
            .map { Int($0)! }

        let earliestPossibleAddress = schedule
            // Filter out states that have have an dependency with entry
            .filter { allDeps.contains($0.ALU0 ?? -1) || allDeps.contains($0.ALU1 ?? -1) || allDeps.contains($0.Mult ?? -1) || allDeps.contains($0.Mem ?? -1) || allDeps.contains($0.Branch ?? -1) }
            // Add latency to them. MUL latency of 3, all else 1
            .map {
                $0.addr + (allDeps.contains($0.Mult ?? -1) ? 3 : 1)
            }
            .max()
        
        // If earliestPossibleAddress is smaller than where block start, use block start, else use it
        return max(
            earliestPossibleAddress ?? 0,
            firstAddrInBlock(block: entry.block, in: schedule)
        )
    }
    
    private func firstAddrInBlock(block: Int, in schedule: [ScheduleRow]) -> Int {
        // Find block start by looking at highest bundle addr of previous block, then adding 1
        block == 0 ? 0 : schedule.last(where: { $0.block == block - 1 })!.addr + 1
    }
    
    private func lastAddrInBlock(block: Int, in schedule: [ScheduleRow]) -> Int {
        // Find block start by looking at highest bundle addr of previous block, then adding 1
        schedule.last(where: { $0.block == block })!.addr
    }

    /// Starts trying to add entry to schedule at index, will increase schedule size if needed, and add earliest possible to the correct unit. Moves down if occupied until not.
    private func addToSchedule(_ entry: DependencyTableEntry, atEarliest index: Int, in schedule: [ScheduleRow]) -> [ScheduleRow] {
        var schedule = schedule
        var i = index
        
        while (true) {
            // If exceed schedule, append empty rows
            while (i >= schedule.count) {
                let newAddr = schedule.isEmpty ? 0 : schedule.map { $0.addr }.max()! + 1
                schedule.append(.init(addr: newAddr, block: entry.block))
            }
            
            // Check if exec unit slot is available and create an updated row
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

    private func update(_ row: ScheduleRow, ifCanBeHandled entry: DependencyTableEntry) -> ScheduleRow? {
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
        
        return combos(elements: entries, k: 2).allSatisfy { combo in
            guard combo.count > 1 else { return true }
            // S(P) + λ(P) ≤ S(C) + II
            let P = combo[0]
            let C = combo[1]
            return S(P) + λ(P) <= S(C) + II
        }
    }
}
