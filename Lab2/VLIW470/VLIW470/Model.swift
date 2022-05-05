//
//  Model.swift
//  VLIW470
//
//  Created by Joel Rudsberg on 2022-05-02.
//

import Foundation

typealias Program = [Instruction]
typealias AllocatedTable = [RegisterAllocRow]
typealias DependencyTable = [DependencyTableEntry]
typealias Schedule = [ScheduleRow]

struct RegisterAllocRow {
    let addr: Address
    var ALU0: Instruction? = nil
    var ALU1: Instruction? = nil
    var Mult: Instruction? = nil
    var Mem: Instruction? = nil
    var Branch: Instruction? = nil
}

struct DependencyTableEntry {
    /// 0 for bb0, 1 for bb1, 2 for bb2
    let block: Int
    let addr: Int
    // let id: String
    let instr: Instruction
    let destReg: String?
    /// If the producer and the consumer are in the same basic block
    let localDep: [String] // ID
    /// If the producer and consumer are in different basic blocks, and the consumer is in the loop body
    let interloopDep: [String]
    let loopInvariantDep: [String]
    let postLoopDep: [String]
}

extension DependencyTableEntry: CustomStringConvertible {
    var description: String {
        "\(addr) – \(instr.name), \(destReg ?? "-"), local: \(localDep), interL: \(interloopDep), loopInv: \(loopInvariantDep), postLoop: \(postLoopDep)"
    }
}

enum ExecutionUnit {
    case ALU
    case Mult
    case Mem
    case Branch
}

typealias Address = Int
struct ScheduleRow: CustomStringConvertible {
    let addr: Address
    let block: Int
    var ALU0: Address? = nil
    var ALU1: Address? = nil
    var Mult: Address? = nil
    var Mem: Address? = nil
    var Branch: Address? = nil
    
    var description: String {
        "\(addr) | ALU0=\(ALU0.toChar), ALU1=\(ALU1.toChar), Mult=\(Mult.toChar), Mem=\(Mem.toChar), Branch=\(Branch.toChar)"
    }
}

protocol Instruction {
    var name: String { get }
    var destReg: String? { get }
    var readRegs: [String]? { get }
    var addr: Int { get }
}

struct ArithmeticInstruction: Instruction {
    var addr: Int
    var name: String {
        mnemonic.rawValue
    }
    var destReg: String? {
        dest.toReg
    }
    var readRegs: [String]? {
        [opA, opB].map { $0.toReg }
    }
    
    let mnemonic: ArithmeticInstructionType
    let dest: Int
    let opA: Int
    let opB: Int // or immediate
}

enum ArithmeticInstructionType: String {
    case add
    case addi
    case sub
    // includes mulu but is executed in Mult unit not ALU
    case mulu
}

struct MemoryInstruction: Instruction {
    var addr: Int
    var name: String {
        mnemonic.rawValue
    }
    var destReg: String? {
        mnemonic == .ld ? destOrSource.toReg : nil
    }
    var readRegs: [String]? {
        let forBoth = [(imm + loadStoreAddr).toReg]
        if mnemonic == .st {
            return forBoth + [destOrSource.toReg]
        } else {
            return forBoth
        }
    }
    
    // dest for load, source for store
    let mnemonic: MemoryInstructionType
    let destOrSource: Int
    let imm: Int
    var loadStoreAddr: Int
}

enum MemoryInstructionType: String {
    case ld
    case st
}

struct LoopInstruction: Instruction {
    var addr: Int
    var name: String {
        type.rawValue
    }
    var destReg: String? {
        nil
    }
    var readRegs: [String]? {
        nil
    }
    
    let type: LoopInstructionType
    let loopStart: Int
}

enum LoopInstructionType: String {
    case loop
    case loop_pip = "loop.pip"
}

struct NoOp: Instruction {
    var addr: Int
    var name: String {
        "noop"
    }
    var destReg: String? {
        nil
    }
    var readRegs: [String]? {
        nil
    }
}

struct MoveInstruction: Instruction {
    var addr: Int
    var name: String {
        "mov"
    }
    /// -1 for LC, -2 for EC
    var destReg: String? {
        reg == -1 ? "LC" : (reg == -2 ? "EC" : reg.toReg)
    }
    var readRegs: [String]? {
        type == .setDestRegWithSourceReg ? [val.toReg] : nil
    }
    
    let type: MoveInstructionType
    let reg: Int
    // bool, imm, or source
    let val: Int
}

enum MoveInstructionType {
    case setPredicateReg
    case setSpecialRegWithImmediate
    case setDestRegWithImmediate
    case setDestRegWithSourceReg
}

extension Int {
    var toReg: String {
        "x\(self)"
    }
}

extension String {
    var regToAddr: Int {
        Int(dropFirst())!
    }
}

extension Sequence where Element == String {
    var regsToAddresses: [Int] {
        self.map { $0.regToAddr }
    }
}

extension Sequence where Element == Instruction {
    var producingInstructions: [Instruction] {
        filter{ $0.destReg != nil && !($0.destReg == "LC" || $0.destReg == "EC") }
    }
    
    var consumingInstructions: [Instruction] {
        filter{ $0.readRegs != nil && !$0.readRegs!.isEmpty }
    }
}

extension Instruction {
    var execUnit: ExecutionUnit {
        if let t = self as? ArithmeticInstruction {
            return t.mnemonic == .mulu ? .Mult : .ALU
        } else if let _ = self as? MoveInstruction {
            return .ALU
        } else if let _ = self as? MemoryInstruction {
            return .Mem
        } else if let _ = self as? LoopInstruction {
            return .Branch
        } else {
            fatalError("Unsupported type")
        }
    }
}
