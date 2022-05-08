//
//  RegisterAllocator.swift
//  VLIW470
//
//  Created by Joel Rudsberg on 2022-05-05.
//

import Foundation

struct RegisterAllocator {
    let depTable: DependencyTable
    
    // MARK: - loop.pip
    func alloc_r(schedule: Schedule) -> AllocatedTable {
        var at = createInitialAllocTable(schedule: schedule, depTable: depTable)
        
        // Phase 1: allocr allocates fresh unique rotating registers to each instruction producing a new value in BB1
        at = allocFreshRegisters_r(at, schedule)
        
        print("\n======= alloc_r allocation =======")
        at.table.enumerated().forEach{ (addr, x) in
            print("\(addr) | ALU0=\(x.ALU0.instr), ALU1=\(x.ALU1.instr), Mult=\(x.Mult.instr), Mem=\(x.Mem.instr), Branch=\(x.Branch.instr)")
        }
        
        return at
    }
    
    private func allocFreshRegisters_r(_ allocTable: AllocatedTable, _ schedule: Schedule) -> AllocatedTable {
        var at = allocTable
        // id -> prev reg, id -> new reg
        let assignJump = schedule.compactMap { $0.stage }.max()!
        let regs = Array(32...95)
        var regToAssignNext = regs[0]
        
        allocTable.table.enumerated().forEach { (bIndex, b) in
            [b.ALU0, b.ALU1, b.Mult, b.Mem, b.Branch].forEach { entry in
                if let instr = entry.instr, instr.isProducingInstruction {
                    // Allocate new fresh register
                    let newReg = "\(regToAssignNext)"
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
                        oldReg: oldReg.regToAddr,
                        newReg: newReg.regToAddr
                    ))
                    
                    regToAssignNext += assignJump
                }
            }
        }
        
        return at
    }
    
    // MARK: - loop
    func alloc_b(schedule: Schedule) -> AllocatedTable {
        var at = createInitialAllocTable(schedule: schedule, depTable: depTable)
        
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
    private func createInitialAllocTable(schedule: Schedule, depTable: DependencyTable) -> AllocatedTable {
        var table: [RegisterAllocRow] = schedule.map {
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
            [b.ALU0, b.ALU1, b.Mult, b.Mem, b.Branch].forEach { entry in
                if let instr = entry.instr, instr.isProducingInstruction {
                    // Allocate new fresh register
                    let newReg = "\(regCounter)"
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
                        oldReg: oldReg.regToAddr,
                        newReg: regCounter
                    ))
                    regCounter += 1
                }
            }
        }
        return at
    }
    
    private func linkRegisters(_ allocTable: AllocatedTable) -> AllocatedTable {
        // All readRegs need to be recomputed.
        var at = allocTable
        print("renamed regs: ", at.renamedRegs)
        allocTable.table.enumerated().forEach { (bIndex, b) in
            [b.ALU0, b.ALU1, b.Mult, b.Mem, b.Branch].forEach { entry in
                if let instr = entry.instr, let readRegs = instr.readRegs, !readRegs.isEmpty  {
                    // Rename each read register
                    // Find what readReg was renamed to
                    // readRegs are pointing to the OLD regs, check renamed regs for those that have match
                    // and return the old regs
                    let block = depTable.first(where: { $0.addr == instr.addr })!.block
                    let newRegs = readRegs.map { oldRegToNewFreshReg(oldReg: $0, block: block, allocTable: allocTable) }
                    
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
        return at
    }
    
    private func oldRegToNewFreshReg(oldReg: String, block: Int, allocTable: AllocatedTable) -> String {
        // If two match then return the one in bb0
        let newRegs = allocTable.renamedRegs
            .filter { oldReg.regToAddr == $0.oldReg }
            .map { ($0.block, $0.newReg.toReg) }
        //        assert(newRegs.count <= 2)
        if newRegs.count == 2 {
            //            return newRegs.first(where: { $0.0 == 0 })!.1
            if block == 1 {
                // TODO: what's the intention to do here???
                // return the one from bb0
                return newRegs.first(where: { $0.0 == 0 })!.1
            } else {
                // return the one from bb1
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
        
        // Find registers that are overwritten in loop, ie interloop dependencies where one must be from bb0
        let bb0 = depTable
            .filter { $0.block == 0 && $0.instr.isProducingInstruction }
            .compactMap { $0.destReg?.regToAddr }
        var oldOverwrittenRegs = depTable
        // If in block 1 and has two interloop dep, then it is of interest
            .filter { $0.block == 1 && $0.interloopDep.count == 2 }
        // Map it to a reg
            .map { loopInstr -> String in
                // The lower of the two deps is the one in bb0
                let addr = max(loopInstr.interloopDep[0].regToAddr, loopInstr.interloopDep[1].regToAddr)
                return depTable[addr].destReg!
            }
        // Remove duplicates
        oldOverwrittenRegs = oldOverwrittenRegs.uniqued()
        
        // Map to what regs now are assigned to
        var newOverwrittenRegs = oldOverwrittenRegs.map { r in
            at.renamedRegs.first(where: { $0.oldReg == r.regToAddr })!.newReg.toReg
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
            let movInstr = MoveInstruction(addr: currAddr, type: .setDestRegWithSourceReg, reg: mov.0.regToAddr, val: mov.1.regToAddr)
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
        var newBundle = RegisterAllocRow(block: 1, addr: currAddr + 1)
        newBundle.Branch = at.table[currAddr].Branch
        at.table.insert(newBundle, at: currAddr + 1)
        
        // Remove loop statement from last bundle
        at.table[currAddr].Branch.instr = nil
        
        return at
    }
}
