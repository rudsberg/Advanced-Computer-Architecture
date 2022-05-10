//
//  RegisterAllocator.swift
//  VLIW470
//
//  Created by Joel Rudsberg on 2022-05-05.
//

import Foundation

struct RegisterAllocator {
    let depTable: DependencyTable
    let schedule: Schedule
    
    // MARK: - loop.pip
    func alloc_r() -> AllocatedTable {
        var at = createInitialAllocTable(depTable: depTable)
        
        // Phase 1: allocr allocates fresh unique rotating registers to each instruction producing a new value in BB1
        at = allocFreshRegisters_r(at)
        
        // Phase 2: alloc nonrotating registers for each loop invariant
        let (nextFreshReg, newTable) = allocNonRotatingRegisters(at)
        at = newTable
        
        // Phase 3: link operands in loop body to its producers
        at = linkOperands_r(at, nextFreshReg: nextFreshReg)
        
        print("\n======= alloc_r allocation =======")
        at.table.enumerated().forEach{ (addr, x) in
            print("\(addr) | ALU0=\(x.ALU0.instr), ALU1=\(x.ALU1.instr), Mult=\(x.Mult.instr), Mem=\(x.Mem.instr), Branch=\(x.Branch.instr)")
        }
        
        return at
    }
    
    private func allocFreshRegisters_r(_ allocTable: AllocatedTable) -> AllocatedTable {
        var at = allocTable
        // id -> prev reg, id -> new reg
        let assignJump = schedule.numStages + 1 // num stages then +1 for equation
        let regs = Array(32...95)
        var indexRegToAssignNext = 0
        
        allocTable.table.enumerated().forEach { (bIndex, b) in
            [b.ALU0, b.ALU1, b.Mult, b.Mem, b.Branch].forEach { entry in
                if let instr = entry.instr, instr.isProducingInstruction, at.table[bIndex].block == 1 {
                    // Allocate new fresh register
                    let newReg = "\(regs[indexRegToAssignNext])"
                    var oldReg: String! = ""
                    switch entry.execUnit {
                    case .ALU(let i):
                        if i == 0 {
                            oldReg = at.table[bIndex].ALU0.instr?.destReg
                            at.table[bIndex].ALU0.instr?.destReg = newReg
                        } else {
                            oldReg = at.table[bIndex].ALU1.instr?.destReg
                            at.table[bIndex].ALU1.instr?.destReg = newReg
                        }
                    case .Mult:
                        oldReg = at.table[bIndex].Mult.instr?.destReg
                        at.table[bIndex].Mult.instr?.destReg = newReg
                    case .Mem:
                        oldReg = at.table[bIndex].Mem.instr?.destReg
                        at.table[bIndex].Mem.instr?.destReg = newReg
                    case .Branch:
                        oldReg = at.table[bIndex].Branch.instr?.destReg
                        at.table[bIndex].Branch.instr?.destReg = newReg
                    }
                    at.renamedRegs.append(.init(
                        id: instr.addr,
                        block: depTable.first(where: { $0.addr == instr.addr })!.block,
                        oldReg: oldReg.regToNum,
                        newReg: newReg.regToNum
                    ))
                    
                    indexRegToAssignNext += assignJump
                }
            }
        }
        
        return at
    }
    
    /// Allocate fresh registers of those dest registers that have one or more invariant dependencies on itself
    private func allocNonRotatingRegisters(_ allocTable: AllocatedTable) -> (Int, AllocatedTable) {
        var at = allocTable
        var nextReg = 1
        let regsToRename = producingOldRegFromDep(deps: { $0.loopInvariantDep }, inBlock: 0).map { $0.1 }
        
        allocTable.table.enumerated().forEach { (bIndex, b) in
            [b.ALU0, b.ALU1, b.Mult, b.Mem, b.Branch].forEach { entry in
                // Retrieve those in bb0 that are invariantly dependent on
                if let instr = entry.instr, let destReg = instr.destReg, regsToRename.contains(destReg), at.table[bIndex].block == 0 {
                    // Allocate new fresh register
                    let newReg = "\(nextReg)"
                    var oldReg: String! = ""
                    switch entry.execUnit {
                    case .ALU(let i):
                        if i == 0 {
                            oldReg = at.table[bIndex].ALU0.instr?.destReg
                            at.table[bIndex].ALU0.instr?.destReg = newReg
                        } else {
                            oldReg = at.table[bIndex].ALU1.instr?.destReg
                            at.table[bIndex].ALU1.instr?.destReg = newReg
                        }
                    case .Mult:
                        oldReg = at.table[bIndex].Mult.instr?.destReg
                        at.table[bIndex].Mult.instr?.destReg = newReg
                    case .Mem:
                        oldReg = at.table[bIndex].Mem.instr?.destReg
                        at.table[bIndex].Mem.instr?.destReg = newReg
                    case .Branch:
                        oldReg = at.table[bIndex].Branch.instr?.destReg
                        at.table[bIndex].Branch.instr?.destReg = newReg
                    }
                    at.nonRotatingRenamedRegs.append(.init(
                        id: instr.addr,
                        block: depTable.first(where: { $0.addr == instr.addr })!.block,
                        oldReg: oldReg.regToNum,
                        newReg: newReg.regToNum
                    ))
                    nextReg += 1
                }
            }
        }
        return (nextReg, at)
    }
    
    /// Given list of dependencies (as addr) return the (bundle, old reg) that is producing that value
    private func producingOldRegFromDep(deps: (DependencyTableEntry) -> [String], inBlock block: Int) -> [(Int, String)] {
        let res = depTable.filter { instr in
            guard instr.block == block, instr.instr.isProducingInstruction else { return false }
            return depTable.contains(where: { depEntry in
                deps(depEntry)
                    .map({ Int($0)! })
                    .contains(instr.instr.addr)
            })
        }
        return res.map { depEntry in
            return (bundle(addr: depEntry.addr, block: block), depEntry.destReg!)
        }
    }
    
    /// Gets the scheduled bundle for addr with PC=addr in given block
    private func bundle(addr: Int, block: Int) -> Int {
        return schedule.rows.filter({ $0.block == block }).first(where: { r in
            let a = addr
            return r.ALU0 == a || r.ALU1 == a || r.Mult == a || r.Mem == a || r.Branch == a
        })!.addr
    }
    
    private func linkOperands_r(_ allocTable: AllocatedTable, nextFreshReg: Int) -> AllocatedTable {
        var at = allocTable
        var regCounter = nextFreshReg
        
        allocTable.table.enumerated().forEach { (bIndex, b) in
            [b.ALU0, b.ALU1, b.Mult, b.Mem, b.Branch].forEach { entry in
                if let instr = entry.instr {
                    let deps = depTable.first(where: { $0.addr == instr.addr })!
                    
                    
                    if let readRegs = instr.readRegs, !readRegs.isEmpty, at.table[bIndex].block == 1 {
                        // For loop invariant dependencies, the register assigned in phase two is read and assigned to the corresponding operand
                        let loopInvDep = deps.loopInvariantDep.map { Int($0)! }
                        if !loopInvDep.isEmpty {
                            let renamed = at.nonRotatingRenamedRegs.first(where: { loopInvDep.contains($0.id) })!
                            at = assignReadReg(renamed.newReg, oldReadReg: renamed.oldReg, in: at, toEntry: entry, atIndex: bIndex)
                        }
                        
                        // For local loop dependencies, the consumed register name needs to be corrected by the number of times RRB changed since the producer wrote to that register.
                        // x_D = x_S + (St(D) − St(S))
                        if instr.addr.toChar == "H" {
                            
                        }
                        let localDep = deps.localDep.map { Int($0)! }
                        if !localDep.isEmpty {
                            assert(localDep.count == 1)
                            let dependentInstr = depTable.first(where: { $0.addr == localDep.first! })!
                            let oldDestReg = dependentInstr.destReg!.regToNum
                            let x_s = at.renamedRegs.first(where: { $0.oldReg == oldDestReg })!.newReg
                            let St_S = stage(bundle: bundle(addr: dependentInstr.addr, block: 1))
                            let St_d = stage(bundle: bundle(addr: instr.addr, block: 1))
                            assert(St_d - St_S >= 0)
                            let x_D = x_s + (St_d - St_S)
                            let oldReadReg = at.renamedRegs.first(where: { $0.oldReg == depTable.first(where: { d in d.addr == localDep[0] })!.destReg!.regToNum })!.oldReg
                            at = assignReadReg(x_D, oldReadReg: oldReadReg, in: at, toEntry: entry, atIndex: bIndex)
                        }
                        
                        // Interloop dependencies
                        // x_D = x_S + (St(D) − St(S)) + 1
                        let interloopDeps = deps.interloopDep.map { Int($0)! }
                        if !interloopDeps.isEmpty {
                            let interloopDepAddr = interloopDeps.max()!
                            // Find the old destReg of instruction at this address
                            let oldDestReg = depTable.first(where: { $0.addr == interloopDepAddr })!.destReg!
                            // Find what it now points to
                            let x_s = at.renamedRegs.first(where: { $0.oldReg == oldDestReg.regToNum })!.newReg
                            let St_S = stage(bundle: bundle(addr: interloopDepAddr, block: 1))
                            let St_d = stage(bundle: bundle(addr: instr.addr, block: 1))
                            assert(St_d - St_S >= 0)
                            let x_D = x_s + (St_d - St_S) + 1
                            let oldReadReg = at.renamedRegs.first(where: { $0.oldReg == depTable.first(where: { d in d.addr == interloopDepAddr })!.destReg!.regToNum })!.oldReg
                            at = assignReadReg(x_D, oldReadReg: oldReadReg, in: at, toEntry: entry, atIndex: bIndex)
                        }
                    }
                    
                    // If an instruction in BB0 is writing to a register r such that r is in the interloop dependency of any instruction of the loop body, the iteration offset is set to 1, the stage offset is set to 0, and the destination register is the same as the producer within the loop.
                    if let destReg = instr.destReg, at.table[bIndex].block == 0 {
                        if depTable.first(where: { $0.interloopDep.map{ $0.regToNum }.contains(instr.addr) }) != nil {
                            // Means there exist an instruction depedent on this destReg
                            // Find this instruction newDestReg and add 1 for offset
                            let newDestReg = at.renamedRegs.first(where: { $0.oldReg == destReg.regToNum })!.newReg + 1
                            
                            // Update instruction
                            at = assignDestReg(newDestReg, in: at, toEntry: entry, atIndex: bIndex)
                        }
                    }
                    
                    // If an instruction in BB2 has a post dependency, it consumes a register produced within the loop body. This register is produced in the last iteration of the loop. As a result, the iteration offset is always zero, and the stage offset is simply the stage distance between the producer and consumer, where the consumer is assumed to be on the last stage of the loop.
                    if at.table[bIndex].block == 2, let readRegs = instr.readRegs, !readRegs.isEmpty {
                        if let postLoopDeps = depTable.first(where: { $0.addr == instr.addr && $0.block == 2 }).map({ $0.postLoopDep }), !postLoopDeps.isEmpty {
                            // Register is producingReg in bb1 + stage offset
                            var oldReadReg: Int!
                            let newReadRegs = postLoopDeps.map { depAddr -> Int in
                                // Resolve register it's depending on
                                let dependentReg = depTable.first(where: { $0.addr == depAddr.regToNum })!.destReg!
                                let renamedReg = at.renamedRegs.first(where: { $0.oldReg == dependentReg.regToNum })!
                                oldReadReg = renamedReg.oldReg
                                let newReg = renamedReg.newReg
                                let stageOffset = schedule.rows.compactMap { $0.stage }.max()! - stage(bundle: bundle(addr: renamedReg.id, block: 1))
                                return newReg + stageOffset
                            }
                            
                            if newReadRegs.count == 1 {
                                // Must ensure other read regs are not potentially overwritten
                                at = assignReadReg(newReadRegs[0], oldReadReg: oldReadReg, in: at, toEntry: entry, atIndex: bIndex)
                            } else {
                                // We can safely overwrite both read regs
                                at = assignReadReg(newReadRegs.map { $0.toReg }, in: at, toEntry: entry, atIndex: bIndex)
                            }
                        }
                    }
                    
                    // If an instruction in BB0 or BB2 reads a loop invariant it is simply assigned to the corresponding operand.
                    // Thus, for each loop invariant set it to newly renamed register
                    if at.table[bIndex].block == 0 || at.table[bIndex].block == 2  {
                        let loopInvDep = deps.loopInvariantDep.map { Int($0)! }
                        if !loopInvDep.isEmpty {
                            let renamed = at.nonRotatingRenamedRegs.first(where: { loopInvDep.contains($0.id) })!
                            at = assignReadReg(renamed.newReg, oldReadReg: renamed.oldReg, in: at, toEntry: entry, atIndex: bIndex)
                        }
                    }
                    
                    // If an instruction has a local dependency within BB0 or BB2, register allocation works in the same way as register allocation without loop.pip
                    // (unless the destination register has already been allocated in Phase 1).
                    // TODO: 
//                    if at.table[bIndex].block == 0 || at.table[bIndex].block == 2, !deps.localDep.isEmpty {
//                        let localDep = deps.localDep.map { Int($0)! }.first!
//                        let dependentReg = depTable.first(where: { $0.addr == localDep })!.destReg!
//                        if at.renamedRegs.contains(where: { $0.oldReg == localDep }) {
//
//                        }
//                    }
                }
            }
        }
        return at
    }
    
    private func stage(bundle: Int) -> Int {
        schedule.rows.first(where: { $0.addr == bundle })!.stage!
    }
    
    private func block(instr: Instruction) -> Int {
        let a = instr.addr
        return schedule.rows.first(where: { r in
            r.ALU0 == a || r.ALU1 == a || r.Mult == a || r.Mem == a || r.Branch == a
        })!.block
    }
    
    private func assignDestReg(_ destReg: Int, in allocTable: AllocatedTable, toEntry entry: RegisterAllocEntry, atIndex index: Int) -> AllocatedTable {
        var at = allocTable
        let newDestReg = "\(destReg)"
        switch entry.execUnit {
        case .ALU(let i):
            if i == 0 {
                at.table[index].ALU0.instr?.destReg = newDestReg
            } else {
                at.table[index].ALU1.instr?.destReg = newDestReg
            }
        case .Mult:
            at.table[index].Mult.instr?.destReg = newDestReg
        case .Mem:
            at.table[index].Mem.instr?.destReg = newDestReg
        case .Branch:
            at.table[index].Branch.instr?.destReg = newDestReg
        }
        
        return at
    }
    
    /// Assigns read reg without checking previous read reg
    private func assignReadReg(_ newReadRegs: [String], in allocTable: AllocatedTable, toEntry entry: RegisterAllocEntry, atIndex index: Int) -> AllocatedTable {
        var at = allocTable
        
        switch entry.execUnit {
        case .ALU(let i):
            if i == 0 {
                at.table[index].ALU0.instr?.readRegs = newReadRegs
            } else {
                at.table[index].ALU1.instr?.readRegs = newReadRegs
            }
        case .Mult:
            at.table[index].Mult.instr?.readRegs = newReadRegs
        case .Mem:
            at.table[index].Mem.instr?.readRegs = newReadRegs
        case .Branch:
            at.table[index].Branch.instr?.readRegs = newReadRegs
        }
        
        return at
    }
    
    private func assignReadReg(_ newReadReg: Int, oldReadReg: Int, in allocTable: AllocatedTable, toEntry entry: RegisterAllocEntry, atIndex index: Int) -> AllocatedTable {
        var at = allocTable
        
        // Must only update the oldReadReg
        func update(instr: Instruction?) -> [String]? {
            if let instr = instr, let readRegs = instr.readRegs?.compactMap({ $0.regToNum }), !readRegs.isEmpty {
                if readRegs.count == 1 {
                    return [newReadReg].map { "\($0)" }
                } else {
                    // pos 1 or 2 that will be updated
                    if readRegs[0] == oldReadReg {
                        return [newReadReg, readRegs[1]].map { "\($0)" }
                    } else {
                        return [readRegs[0], newReadReg].map { "\($0)" }
                    }
                }
            } else {
                return nil
            }
        }
        
        switch entry.execUnit {
        case .ALU(let i):
            if i == 0 {
                let instr = at.table[index].ALU0.instr
                at.table[index].ALU0.instr?.readRegs = update(instr: instr)
            } else {
                let instr = at.table[index].ALU1.instr
                at.table[index].ALU1.instr?.readRegs = update(instr: instr)
            }
        case .Mult:
            let instr = at.table[index].Mult.instr
            at.table[index].Mult.instr?.readRegs = update(instr: instr)
        case .Mem:
            let instr = at.table[index].Mem.instr
            at.table[index].Mem.instr?.readRegs = update(instr: instr)
        case .Branch:
            let instr = at.table[index].Branch.instr
            at.table[index].Branch.instr?.readRegs = update(instr: instr)
        }
        
        return at
    }
    
    // MARK: - loop
    func alloc_b() -> AllocatedTable {        
        var at = createInitialAllocTable(depTable: depTable)
        
        // Phase 1: Allocate fresh unique registers to each instruction producing a new value
        // Output: all destinations registers specified
        at = allocFreshRegisters_b(at)
        
        // Phase 2: Link each operand to the registers newly allocated in phase 1
        // If two dependencies, must be in bb0 and bb1, then use register of bb0. Incorrectness resolved in phase 3.
        // Output: all operand registers specified
        at = linkRegisters(at)
        
        // Phase 3: Fix the interloop dependencies
        at = fixInterLoopDep(at)
        
        print("\n======= alloc_b allocation =======")
        at.table.enumerated().forEach{ (addr, x) in
            print("\(addr) | ALU0=\(x.ALU0.instr), ALU1=\(x.ALU1.instr), Mult=\(x.Mult.instr), Mem=\(x.Mem.instr), Branch=\(x.Branch.instr)")
        }
        
        return at
    }
    
    /// Maps schedule to alloc table, containing the instructions rather than only their original address
    private func createInitialAllocTable(depTable: DependencyTable) -> AllocatedTable {
        var table: [RegisterAllocRow] = schedule.rows.map {
            func find(_ addr: Int?, _ unit: ExecutionUnit) -> RegisterAllocEntry {
                if let addr = addr {
                    return .init(execUnit: unit, instr: depTable[addr].instr)
                } else {
                    return .init(execUnit: unit)
                }
            }
            
            return .init(
                block: $0.block,
                addr: $0.addr,
                addrWithStage: $0.addrWithStage,
                ALU0: find($0.ALU0, .ALU(0)),
                ALU1: find($0.ALU1, .ALU(1)),
                Mult: find($0.Mult, .Mult),
                Mem: find($0.Mem, .Mem),
                Branch: find($0.Branch, .Branch)
            )
        }
        
        // Update the loop address
        if let i = table.firstIndex(where: { $0.Branch.instr != nil }) {
            var loopInstr = table[i].Branch.instr as! LoopInstruction
            loopInstr.loopStart = table.firstIndex(where: { $0.block == 1 })!
            table[i].Branch.instr = loopInstr
        }
        
        return .init(table: table, renamedRegs: [])
    }
    
    private func allocFreshRegisters_b(_ allocTable: AllocatedTable) -> AllocatedTable {
        var at = allocTable
        var regCounter = 1
        allocTable.table.enumerated().forEach { (bIndex, b) in
            let (newRow, newCounter, newRenamedRegs) = allocFreshRegisters(forRow: at.table[bIndex], startRegCounter: regCounter)
            regCounter = newCounter
            at.table[bIndex] = newRow
            at.renamedRegs.append(contentsOf: newRenamedRegs)
        }
        return at
    }
    
    /// Updates row and returns next regCounter that can be used, and newly renamed regs
    private func allocFreshRegisters(forRow row: RegisterAllocRow, startRegCounter: Int) -> (RegisterAllocRow, Int, [RenamedReg]) {
        var regCounter = startRegCounter
        var b = row
        var renamedRegs = [RenamedReg]()
        [b.ALU0, b.ALU1, b.Mult, b.Mem, b.Branch].forEach { entry in
            if let instr = entry.instr, instr.isProducingInstruction {
                // Allocate new fresh register
                let newReg = "\(regCounter)"
                var oldReg: String! = ""
                switch entry.execUnit {
                case .ALU(let i):
                    if i == 0 {
                        oldReg = b.ALU0.instr?.destReg
                        b.ALU0.instr?.destReg = newReg
                    } else {
                        oldReg = b.ALU1.instr?.destReg
                        b.ALU1.instr?.destReg = newReg
                    }
                case .Mult:
                    oldReg = b.Mult.instr?.destReg
                    b.Mult.instr?.destReg = newReg
                case .Mem:
                    oldReg = b.Mem.instr?.destReg
                    b.Mem.instr?.destReg = newReg
                case .Branch:
                    oldReg = b.Branch.instr?.destReg
                    b.Branch.instr?.destReg = newReg
                }
                renamedRegs.append(.init(
                    id: instr.addr,
                    block: depTable.first(where: { $0.addr == instr.addr })!.block,
                    oldReg: oldReg.regToNum,
                    newReg: regCounter
                ))
                regCounter += 1
            }
        }
        return (b, regCounter, renamedRegs)
    }
    
    private func linkRegisters(_ allocTable: AllocatedTable) -> AllocatedTable {
        // All readRegs need to be recomputed.
        var at = allocTable
        allocTable.table.enumerated().forEach { (bIndex, b) in
            [b.ALU0, b.ALU1, b.Mult, b.Mem, b.Branch].forEach { entry in
                if let instr = entry.instr, let readRegs = instr.readRegs, !readRegs.isEmpty {
                    // Rename each read register
                    // Find what readReg was renamed to
                    // readRegs are pointing to the OLD regs, check renamed regs for those that have match
                    let block = depTable.first(where: { $0.addr == instr.addr })!.block
                    let newRegs = readRegs.compactMap { oldRegToNewFreshReg(oldReg: $0, block: block, allocTable: allocTable) }
                    
                    if !newRegs.isEmpty {
                        switch entry.execUnit {
                        case .ALU(let i):
                            if i == 0 {
                                at.table[bIndex].ALU0.instr?.readRegs = newRegs
                            } else {
                                at.table[bIndex].ALU1.instr?.readRegs = newRegs
                            }
                        case .Mult:
                            at.table[bIndex].Mult.instr?.readRegs = newRegs
                        case .Mem:
                            at.table[bIndex].Mem.instr?.readRegs = newRegs
                        case .Branch:
                            at.table[bIndex].Branch.instr?.readRegs = newRegs
                        }
                    }
                }
            }
        }
        return at
    }
    
    private func oldRegToNewFreshReg(oldReg: String, block: Int, allocTable: AllocatedTable) -> String? {
        // If two match then return the one in bb0
        let newRegs = allocTable.renamedRegs
            .filter { oldReg.regToNum == $0.oldReg }
            .map { ($0.block, $0.newReg.toReg) }
        
        if newRegs.isEmpty {
            return nil
        }
        
        if newRegs.count == 2 {
            if block == 1 {
                return newRegs.first(where: { $0.0 == 0 })!.1
            } else {
                return newRegs.first(where: { $0.0 == 1 })!.1
            }
        } else {
            return newRegs[0].1
        }
    }
    
    /// View - see loop body as a function and interloop dependencies as function parameters.
    /// Since we choose dest register r produced in bb0 as operands for consumers in bb1 (for those with dep in bb0)
    /// those registers are effectively like function arguments. Thus, values produced in bb1 that actually point to
    /// same register as in bb0 must be moved to r to respect the 'calling conventions'. Do this by *inserting* mov
    /// instructions at last bundle of loop, creating space if needed (pushing down loop). NOTE: instruction dep must
    /// be checked to not be violated.
    private func fixInterLoopDep(_ allocTable: AllocatedTable) -> AllocatedTable {
        var at = allocTable
        
        var oldOverwrittenRegs = depTable
        // If in block 1 and has two interloop dep, then it is of interest
            .filter { $0.block == 1 && $0.interloopDep.count == 2 }
        // Map it to a reg
            .map { loopInstr -> String in
                // The lower of the two deps is the one in bb0
                let addr = max(loopInstr.interloopDep[0].regToNum, loopInstr.interloopDep[1].regToNum)
                return depTable[addr].destReg!
            }
        // Remove duplicates
        oldOverwrittenRegs = oldOverwrittenRegs.uniqued()
        
        // Map to what regs now are assigned to
        var newOverwrittenRegs = oldOverwrittenRegs.map { r in
            at.renamedRegs.first(where: { $0.oldReg == r.regToNum })!.newReg.toReg
        }
        newOverwrittenRegs = newOverwrittenRegs.uniqued()
        
        // It's the second entry in the renamed regs matching the old overwritten regs
        let sourceRegs = oldOverwrittenRegs.map { oldReg in
            at.renamedRegs.filter { $0.oldReg.toReg == oldReg }[1].newReg.toReg
        }
        
        // Schedule the mov instructions.
        assert(newOverwrittenRegs.count == sourceRegs.count)
        // sourceRegs point to instructions in loop and must respect dependencies
        // Try insert at last bundle - if bundle ALUs busy or instruction dep is broken,
        // create new bundle, move down branch, and try again.
        // Only mul instruction may cause movs depedency to be violated.
        // Check if mult exists such that they need to be moved down
        let dependencies: [(String, Int)] = at.table
            .filter { $0.block == 1 && $0.Mult.instr != nil &&
                $0.Mult.instr!.isProducingInstruction && sourceRegs.contains($0.Mult.instr!.destReg!) }
            .map { entry in
                (sourceRegs.first(where: { $0 == entry.Mult.instr!.destReg! })!, entry.addr + 3) }
        
        // (String : destReg, String : srcReg, Int? : earliest possible schedule addr)
        let movs = zip(newOverwrittenRegs, sourceRegs).map { tup -> (String, String, Int?) in
            let src = tup.1
            let earliestAddr = dependencies.first { (reg, addr) in
                reg == src
            }?.1
            return (tup.0, tup.1, earliestAddr)
        }
        
        movs.forEach { mov in
            var currAddr = at.table.first(where: { $0.Branch.instr != nil })!.addr
            
            // Check dependency
            while mov.2 != nil && mov.2! > currAddr {
                at = insertBundleAndHandleJump(at, startAddr: currAddr)
                currAddr += 1
            }
            
            // Now dependency dealt with, still risk ALU is in use, check then assign
            let movInstr = MoveInstruction(addr: currAddr, type: .setDestRegWithSourceReg, reg: mov.0.regToNum, val: mov.1.regToNum)
            if at.table[currAddr].ALU0.instr == nil {
                at.table[currAddr].ALU0.instr = movInstr
            } else if at.table[currAddr].ALU1.instr == nil {
                at.table[currAddr].ALU1.instr = movInstr
            } else {
                // Insert one new bundle then add instruction
                at = insertBundleAndHandleJump(at, startAddr: currAddr)
                at.table[currAddr + 1].ALU0.instr = movInstr
            }
        }
        
        return at
    }
    
    private func insertBundleAndHandleJump(_ allocTable: AllocatedTable, startAddr currAddr: Int) -> AllocatedTable {
        var at = allocTable
        
        // Insert new bundle
        var newBundle = RegisterAllocRow(block: 1, addr: currAddr + 1, addrWithStage: nil)
        newBundle.Branch = at.table[currAddr].Branch
        at.table.insert(newBundle, at: currAddr + 1)
        
        // Remove loop statement from last bundle
        at.table[currAddr].Branch.instr = nil
        
        return at
    }
}
