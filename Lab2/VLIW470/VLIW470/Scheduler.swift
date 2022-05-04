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
        
        print("\n======= Schedule =======")
        schedule.forEach({ print($0) })
         
        return schedule.map { $0.1 }
    }
    
    private func earliestScheduledStage(for entry: DependencyTableEntry, in schedule: [ScheduleRow]) -> Int {
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
    private func addToSchedule(_ entry: DependencyTableEntry, atEarliest index: Int, in schedule: [ScheduleRow]) -> [ScheduleRow] {
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

    private func updateSchedule(entries: [DependencyTableEntry], schedule: [ScheduleRow]) -> [ScheduleRow] {
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
}
