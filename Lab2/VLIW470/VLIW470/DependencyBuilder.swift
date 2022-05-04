//
//  DependencyBuilder.swift
//  VLIW470
//
//  Created by Joel Rudsberg on 2022-05-04.
//

import Foundation

struct DependencyBuilder {
    func createTable(fromProgram program: [(Int, Instruction)]) -> [DependencyTableEntry] {
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
        
        return depTable
    }
    
    /// Finds dependencies
    private func findDependencies(in instructions: [(Int, Instruction)], for instruction: Instruction) -> [String] {
        let RAW = instructions.filter {
            guard let readRegs = instruction.readRegs, let destReg = $0.1.destReg else {
                return false
            }
            return readRegs.contains(destReg)
        }
        return RAW.map { "\($0.0)" }
    }

}
