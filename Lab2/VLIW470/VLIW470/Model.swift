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
    var ALU0 = RegisterAllocEntry(execUnit: .ALU(0))
    var ALU1 = RegisterAllocEntry(execUnit: .ALU(1))
    var Mult = RegisterAllocEntry(execUnit: .Mult)
    var Mem = RegisterAllocEntry(execUnit: .Mem)
    var Branch = RegisterAllocEntry(execUnit: .Branch)
}

struct RegisterAllocEntry {
    let execUnit: ExecutionUnit
    var instr: Instruction? = nil
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

enum ExecutionUnit: Equatable {
    case ALU(Int)
    case Mult
    case Mem
    case Branch
    
//    static func ==(lhs: ExecutionUnit, rhs: ExecutionUnit) -> Bool {
//        if case let ExecutionUnit.ALU(i1) = lhs, case let ExecutionUnit.ALU(i2) = rhs {
//            return i1 == i2
//        } else {
//            return lhs == .Mem && rhs == .Mem || lhs == .Mult && rhs == .Mult || lhs == .Branch && rhs == .Branch
//        }
//    }
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

protocol Instruction: CustomStringConvertible {
    var name: String { get }
    var destReg: String? { get set }
    var readRegs: [String]? { get }
    var addr: Int { get }
}

extension Instruction {
    var description: String {
        let a: Int? = addr
        return "\(a.toChar): \(name) dest=\(destReg), read=\(readRegs)"
    }
}

struct ArithmeticInstruction: Instruction {
    var addr: Int
    var name: String {
        mnemonic.rawValue
    }
    var destReg: String? {
        get { dest.toReg }
        set { self.dest = newValue != nil ? Int(newValue!)! : self.dest }
    }
    var readRegs: [String]? {
        [opA, opB].map { $0.toReg }
    }
    
    let mnemonic: ArithmeticInstructionType
    var dest: Int
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
        get { mnemonic == .ld ? destOrSource.toReg : nil }
        set { self.destOrSource = mnemonic == .ld ? (newValue != nil ? Int(newValue!)! : self.destOrSource) : self.destOrSource }
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
    var destOrSource: Int
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
        get { nil }
        set {}
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
        get { nil }
        set {}
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
        get { reg == -1 ? "LC" : (reg == -2 ? "EC" : reg.toReg) }
        set { reg = reg == -1 || reg == -2 ? reg : (newValue != nil ? Int(newValue!)! : self.reg) }
    }
    var readRegs: [String]? {
        type == .setDestRegWithSourceReg ? [val.toReg] : nil
    }
    
    let type: MoveInstructionType
    var reg: Int
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
        filter { $0.isProducingInstruction }
    }
    
    var consumingInstructions: [Instruction] {
        filter{ $0.readRegs != nil && !$0.readRegs!.isEmpty }
    }
}

extension Instruction {
    var isProducingInstruction: Bool {
        destReg != nil && !(destReg == "LC" || destReg == "EC")
    }
    
    var execUnit: ExecutionUnit {
        if let t = self as? ArithmeticInstruction {
            return t.mnemonic == .mulu ? .Mult : .ALU(0) // 0 disregarded
        } else if let _ = self as? MoveInstruction {
            return .ALU(0) // 0 disregarded
        } else if let _ = self as? MemoryInstruction {
            return .Mem
        } else if let _ = self as? LoopInstruction {
            return .Branch
        } else {
            fatalError("Unsupported type")
        }
    }
}
