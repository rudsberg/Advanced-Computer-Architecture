//
//  Scheduling.swift
//  VLIW470
//
//  Created by Joel Rudsberg on 2022-05-04.
//

import Foundation
import Algorithms

struct Scheduler {
    let depTable: DependencyTable
    
    // MARK: - loop.pip scheduling
    func schedule_loop_pip() -> Schedule {
        var schedule = Schedule()
        
        var II = minimalII()
        while true {
            if let newSchedule = createSchedulePip(II: II) {
                print("✅ pip schedule success for II \(II)")
                if equationHolds(for: newSchedule, II: II) {
                    print("✅ for II \(II)")
                    schedule = newSchedule
                    break
                } else {
                    print("🔴 for II \(II)")
                    II += 1
                }
            } else {
                print("🔴 pip failed schedule for II \(II)")
                II += 1
            }
        }
        
        print("\n======= Schedule pip =======")
        schedule.forEach({ print($0) })
        
        return schedule
    }
    
    private func createSchedulePip(II: Int) -> Schedule? {
        var schedule = Schedule()
        
        // Start from minimal II and schedule using that
        let loopInstr = depTable.filter { $0.block == 1 }
        let loopStages = Int(
            ceil(Double(loopInstr.count) / Double(II))
        )
        
        var hasCreatedLoop = false
        var failed = false
        depTable.forEach { entry in
            // Scheduling stage 0 and 2 is identical to loop
            if entry.block == 0 || entry.block == 2 {
                schedule = addToSchedule(entry, in: schedule)
            } else {
                // Create the loop bundles and divide into stages
                if !hasCreatedLoop {
                    // Create the loop with the stages
                    for stage in 0...loopStages-1 {
                        for offsetInStage in 0...II-1 {
                            schedule.append(.init(
                                addr: schedule.filter { $0.block == 0 }.count + stage*II + offsetInStage,
                                addrWithStage: schedule.filter { $0.block == 0 }.count + offsetInStage,
                                stage: stage,
                                block: 1
                            ))
                        }
                    }
                    hasCreatedLoop = true
                }
                
                if let newSchedule = scheduleEntryPip(entry, schedule: schedule, loopStages: loopStages, II: II) {
                    schedule = newSchedule
                } else {
                    failed = true
                }
            }
        }
        
        if failed {
            return nil
        } else {
            return schedule
        }
    }
    
    /// Assumes entries have been created before s
    private func scheduleEntryPip(_ entry: DependencyTableEntry, schedule: Schedule, loopStages: Int, II: Int) -> Schedule? {
        // S[s][i][j] the slot in schedule S, stage s, bundle with address (in program memory) i, and corresponding to the execution unit j
        // Try schedule instruction starting from stage 0, trying until last stage,
        // checking if S is violated + the same checks as in loop
        for stage in 0...loopStages-1 {
            // Check for same contraints as in loop
            // Branch instr can always be scheduled
            var earliestAddr: Int?
            if entry.instr.execUnit != .Branch {
                // Earliest stage must be less than or eqal of max addr of current stage
                earliestAddr = earliestScheduledBundle(for: entry, in: schedule)
                let maxAddrInStage = schedule.filter({ $0.block == 1 && $0.stage! == stage }).map({ $0.addr }).max()!
                if earliestAddr! > maxAddrInStage {
                    continue
                }
                
                // Must be at least one exec unit left in current stage
                if execUnitBusyInStage(stage: stage, earliestAddr: earliestAddr!, maxAddrInStage: maxAddrInStage, entry: entry, schedule: schedule) {
                    continue
                }
            } else {
                // Schedule loop in the first stage
                let i = schedule.lastIndex(where: { $0.block == 1 && $0.stage == 0 })!
                var s = schedule
                s[i].Branch = entry.addr
                return s
            }
            
            // Getting here means no constraints are followed and exec unit not busy
            // Check for resource contention until we go outside current stage
            // Contentions means same addrWithStage already occupies the exec unit
            // Check all exec units within current stage
            let (_, firstPossibleAddrToAdd) = addToSchedule(entry, atEarliest: earliestAddr!, in: schedule)
            
            // From firstPossibleAddrToAdd, check each bundle within current stage, if found one that is
            // not violating contention, then schedule on this spot
            for bundle in schedule.filter({ $0.stage == stage && $0.addr >= firstPossibleAddrToAdd }) {
                // Check if it violates contention
                let conflictingRows = schedule.filter({
                    // Same row another stage & exec unit busy
                    $0.addrWithStage == bundle.addrWithStage && $0.unitBusy(unit: entry.instr.execUnit)
                })
                
                if conflictingRows.isEmpty {
                    let (newSchedule, _) = addToSchedule(entry, atEarliest: bundle.addr, in: schedule)
                    return newSchedule
                }
            }
        }
        
        return nil
    }
    
    private func execUnitBusyInStage(stage: Int, earliestAddr: Int, maxAddrInStage: Int, entry: DependencyTableEntry, schedule: Schedule) -> Bool {
        var currAddr = earliestAddr
        while (currAddr <= maxAddrInStage) {
            if nil != update(schedule[currAddr], ifCanBeHandled: entry) {
                return false
            }
            currAddr += 1
        }
        return true
    }
        
    // MARK: - loop scheduling
    /// Output: valid schedule table, i.e. what each execution unit should perform each stage for the 3 basic blocks. Addr | ALU0 | ALU1 | Mult | Mem | Branch
    /// Picks instruction in sequential order, checks the dependencies in table, and schedules the instruction in the earliest possible slot
    /// All instructions must obey: S(P) + λ(P) ≤ S(C) + II, if violation, recompute by increasing II
    func schedule_loop() -> Schedule {
        var schedule = Schedule()
        schedule = createLoopSchedule(depTable: depTable)
        
        // Ensures II is obeyed
        schedule = recomputeIfNeeded(schedule: schedule)
        
        // Print for debugging
        print("\n======= Schedule =======")
        schedule.forEach({ print($0) })
         
        return schedule
    }
    
    private func createLoopSchedule(depTable: DependencyTable) -> Schedule {
        var schedule = Schedule()
        depTable.forEach { entry in
            schedule = addToSchedule(entry, in: schedule)
        }
        return schedule
    }
    
    private func addToSchedule(_ entry: DependencyTableEntry, in schedule: Schedule) -> Schedule {
        var schedule = schedule
        let stage = earliestScheduledBundle(for: entry, in: schedule)
        let (s, _) = addToSchedule(entry, atEarliest: stage, in: schedule)
        schedule = s
        return schedule
    }
    
    /// Finds earliest possible bundle to schedule entry within it's block (bb0/1/2) by analyzing its dependencies. Does not check if execution units are busy or not.
    private func earliestScheduledBundle(for entry: DependencyTableEntry, in schedule: Schedule) -> Int {
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
    
    private func firstAddrInBlock(block: Int, in schedule: Schedule) -> Int {
        // Find block start by looking at highest bundle addr of previous block, then adding 1
        block == 0 ? 0 : schedule.last(where: { $0.block == block - 1 })!.addr + 1
    }
    
    private func lastAddrInBlock(block: Int, in schedule: Schedule) -> Int {
        // Find block start by looking at highest bundle addr of previous block, then adding 1
        schedule.last(where: { $0.block == block })!.addr
    }

    /// Starts trying to add entry to schedule at index, will increase schedule size if needed, and add earliest possible to the correct unit. Moves down if occupied until not.
    /// Assumes index is a valid spot, obeying dependencies.
    /// Return new schedule and addr of where it was added
    private func addToSchedule(_ entry: DependencyTableEntry, atEarliest index: Int, in schedule: Schedule) -> (Schedule, Int) {
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
                break
            } else {
                i += 1
            }
        }

        return (schedule, i)
    }
    
    /// Checks the exec unit and updates if not occupied
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
    
    /// Recomputes the schedule if needed, depending on the II
    private func recomputeIfNeeded(schedule: Schedule) -> Schedule {
        var schedule = schedule
        let initialII = minimalII()
        let validII = validII(for: schedule, initialII: initialII)
        if initialII < validII {
            // Move down the instruction the difference of initialII and validII
            let moveDistance = validII - initialII
            
            // Insert new bundles between loop and bb2
            let oldLoopIndex = schedule.firstIndex(where: { $0.Branch != nil })!
            let newLoopIndex = oldLoopIndex + moveDistance
            var currInsertIndex = oldLoopIndex + 1
            // Insert empty bundles until we reach the new loop index
            while (currInsertIndex != newLoopIndex) {
                schedule.insert(.init(addr: currInsertIndex, block: 1), at: currInsertIndex)
                currInsertIndex += 1
            }
            assert(currInsertIndex == newLoopIndex)
            
            // Insert the new bundle with the loop instruction
            var newBundle = ScheduleRow(addr: newLoopIndex, block: 1)
            newBundle.Branch = schedule[oldLoopIndex].Branch!
            schedule.insert(newBundle, at: newLoopIndex)
            
            // Remove the branch instruction from old position
            schedule[oldLoopIndex].Mem = nil
        }
        return schedule
    }
    
    private func minimalII() -> Int {
        guard !depTable.filter({ $0.block == 1 }).isEmpty else {
            return 0
        }
        
        // ALU, MULT, MEM, BRANCH
        let numUnits: [Double] = [2, 1, 1, 1]
        var instrPerExecUnit: [Double] = [0, 0, 0, 0]
        depTable.filter { $0.block == 1 }.forEach { entry in
            let instr = entry.instr
            instrPerExecUnit[instr.execUnit.i] += 1
        }
        let res = instrPerExecUnit.enumerated().map { (i, numInstr) in
            ceil(numInstr / numUnits[i])
        }.max()!
        
        return Int(res)
    }
    
    private func validII(for schedule: Schedule, initialII: Int) -> Int {
        var II = initialII
        while !equationHolds(for: schedule, II: II) {
            print("Invalid schedule for II \(II)")

            // Increment II until we find a valid one
            II += 1
        }
        print("Valid schedule for II=\(II) ✅")
        return II
    }

    /// Check if equation holds for all interloop instructions. If not, increase II and try again
    private func equationHolds(for schedule: Schedule, II: Int) -> Bool {
        let loopInstructions = schedule.filter { $0.block == 1 }
        // Group by ALU types
        let iALU0 = loopInstructions.filter { $0.ALU0 != nil }.map { ($0.addr, ExecutionUnit.ALU(0)) }
        let iALU1 = loopInstructions.filter { $0.ALU1 != nil }.map { ($0.addr, ExecutionUnit.ALU(1)) }
        let Mult = loopInstructions.filter { $0.Mult != nil }.map { ($0.addr, ExecutionUnit.Mult) }
        let Mem = loopInstructions.filter { $0.Mem != nil }.map { ($0.addr, ExecutionUnit.Mem) }
        let Branch = loopInstructions.filter { $0.Branch != nil }.map { ($0.addr, ExecutionUnit.Branch) }
        
        return [iALU0, iALU1, Mult, Mem, Branch].allSatisfy { equationHolds(for: $0, II: II) }
    }
    
    private func equationHolds(for entries: [(Address, ExecutionUnit)], II: Int) -> Bool {
        // Filter out those with interloop dependencies
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
