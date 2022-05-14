//
//  DependencyBuilder.swift
//  VLIW470
//
//  Created by Joel Rudsberg on 2022-05-04.
//

import Foundation

struct DependencyBuilder {
    func createTable(fromProgram program: Program) -> DependencyTable {
        var depTable = DependencyTable()
        
        /// One before loopStart
        let (loopStart, loopEnd) = program.reduce((0, 0), { acc, ins in
            if let instuction = ins as? LoopInstruction {
                return (instuction.loopStart, ins.addr)
            } else {
                return acc
            }
        })
        
        let bb0 = Array(program.prefix(loopStart))
        let bb1 = Array(program.dropFirst(loopStart).prefix(loopEnd - loopStart + 1))
        let bb2 = Array(program.dropFirst(loopEnd + 1))
        let blockInfo = bb0.map { ($0.addr, 0) } + bb1.map { ($0.addr, 1) } + bb2.map { ($0.addr, 2) }

        bb0.forEach { i in
            let entry = DependencyTableEntry(
                block: 0,
                addr: i.addr,
                instr: i,
                destReg: i.destReg,
                localDep: findDependencies(in: Array(bb0.prefix(i.addr)), for: i, blockInfo: blockInfo),
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
                let destReg = assignedI.destReg!
                return !bb1.contains(where: { $0.destReg == destReg })
            }
            // An operand of instruction A has an interloop dependency if it is either produced within the loop body,
            // after A in sequential program order, or before the loop, in BB0 (or both).
            // Thus: take instructions after i and in bb0
            if i.addr.toChar == "J" {
                
            }
            var consideredInterLoopInstructions = bb0.producingInstructions + bb1.dropFirst(i.addr - loopStart).producingInstructions
            consideredInterLoopInstructions = consideredInterLoopInstructions.filter { i in !consideredLoopInvInstructions.contains(where: { $0.addr == i.addr }) }
            let entry = DependencyTableEntry(
                block: 1,
                addr: i.addr,
                instr: i,
                destReg: i.destReg,
                // Search dep those before curr instr in same block
                localDep: findDependencies(in: Array(bb1.prefix(i.addr - loopStart)), for: i, blockInfo: blockInfo),
                interloopDep: findDependencies(in: consideredInterLoopInstructions, for: i, blockInfo: blockInfo),
                loopInvariantDep: findDependencies(in: consideredLoopInvInstructions, for: i, blockInfo: blockInfo),
                postLoopDep: []
            )
            depTable.append(entry)
        }

        bb2.forEach { i in
            let entry = DependencyTableEntry(
                block: 2,
                addr: i.addr,
                instr: i,
                destReg: i.destReg,
                localDep: findDependencies(in: Array(bb2.prefix(i.addr - loopEnd - 1)), for: i, blockInfo: blockInfo),
                interloopDep: [],
                loopInvariantDep: [],
                // Producer in bb1 and consumer in bb2
                postLoopDep: findDependencies(in: bb1, for: i, blockInfo: blockInfo)
            )
            depTable.append(entry)
        }
        
        print("======= Dependency Table =======")
        depTable.forEach({ print($0) })
        
        return depTable
    }
    
    /// Finds dependencies
    /// Prune determines if we apply: if dependent on more than one instruction for the same register, only take the last producing instruction in program order
    private func findDependencies(in instructions: Program, for instruction: Instruction, blockInfo: [(Int, Int)]) -> [String] {
        guard let readRegs = instruction.readRegs else {
            return []
        }
        
        // (addr, destReg, block)
        var RAW: [(Int, String, Int)] = instructions.filter {
            guard let destReg = $0.destReg else {
                return false
            }
            return readRegs.contains(destReg)
        }.map { i in
            (i.addr, i.destReg!, blockInfo.first(where: { b in b.0 == i.addr })!.1)
        }
        
        // No duplicate for same producing reg IF in same block, get it by going in reverse order and only add if not present
        var _RAW = [(Int, String, Int)]()
        RAW.sorted { x1, x2 in
            x1.0 > x2.0
        }.forEach { dep in
            // If not same dest reg AND in same blocka
            if !_RAW.contains(where: { x in x.1 == dep.1 && x.2 == dep.2 }) {
                _RAW.append(dep)
            }
        }
        RAW = _RAW
        
        var RAW_Addr = RAW.map { $0.0 }.sorted(by: <)
        RAW_Addr = RAW_Addr.uniqued()
        
        return RAW_Addr.map { "\($0)" }
    }

}
