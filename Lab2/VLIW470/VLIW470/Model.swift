//
//  Model.swift
//  VLIW470
//
//  Created by Joel Rudsberg on 2022-05-02.
//

import Foundation

typealias Program = [Instruction]
typealias DependencyTable = [DependencyTableEntry]

struct AllocatedTable {
    var table: [RegisterAllocRow]
    /// Collects the registers we have renamed. (Old, New).
    /// For alloc_b this is all regs, for alloc_r is the instructions producing new values in bb1
    var renamedRegs: [RenamedReg]
    /// For alloc_b: non-rotating registers that have been renamed
    var nonRotatingRenamedRegs: [RenamedReg] = []
}

struct RenamedReg {
    /// Initial program addr
    let id: Int
    let block: Int
    let oldReg: Address
    let newReg: Address
}

struct RegisterAllocRow {
    let block: Int
    var addr: Address
    let addrWithStage: Address?
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
    // TODO: refactor into String
    let localDep: [String] // ID
    /// If the producer and consumer are in different basic blocks, and the consumer is in the loop body
    let interloopDep: [String]
    // TODO: refactor into String
    let loopInvariantDep: [String]
    // TODO: refactor into String
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
    
    var i: Int {
        switch self {
        case .ALU(_):
            return 0
        case .Mult:
            return 1
        case .Mem:
            return 2
        case .Branch:
            return 3
        }
    }
}

struct Schedule {
    var II = 0
    var rows = [ScheduleRow]()
    var numStages: Int {
        rows.compactMap { $0.stage }.max()! + 1
    }
}

typealias Address = Int
struct ScheduleRow: CustomStringConvertible {
    let addr: Address
    var addrWithStage: Address? = nil
    var stage: Address? = nil
    let block: Int
    var ALU0: Address? = nil
    var ALU1: Address? = nil
    var Mult: Address? = nil
    var Mem: Address? = nil
    var Branch: Address? = nil
    
    var description: String {
        let stage: String = stage != nil ? "\t| \(stage!)" : ""
        return "\(addr) | ALU0=\(ALU0.toChar), ALU1=\(ALU1.toChar), Mult=\(Mult.toChar), Mem=\(Mem.toChar), Branch=\(Branch.toChar)" + stage
    }
    
    func unitBusy(unit: ExecutionUnit) -> Bool {
        switch unit {
        case .ALU(let i):
            if i == 0 {
                return ALU0 != nil
            } else {
                return ALU1 != nil
            }
        case .Mult:
            return Mult != nil
        case .Mem:
            return Mem != nil
        case .Branch:
            return Branch != nil
        }
    }
}

protocol Instruction: CustomStringConvertible {
    var name: String { get }
    var destReg: String? { get set }
    var readRegs: [String]? { get set }
    var addr: Int { get set }
    var print: String { get }
}

extension Instruction {
    var description: String {
        let a: Int? = addr
        return "\(a.toChar): \(name) dest=\(destReg), read=\(readRegs)"
    }
}

extension Optional where Wrapped == Instruction {
    var string: String {
        self == nil ? "nop" : self!.print
    }
}

struct ArithmeticInstruction: Instruction {
    var print: String {
        "\(mnemonic.rawValue) \(dest.toReg), \(opA.toReg), \(mnemonic == .addi ? "\(opB)" : opB.toReg)"
    }
    var addr: Int
    var name: String {
        mnemonic.rawValue
    }
    var destReg: String? {
        get { dest.toReg }
        set { self.dest = newValue != nil ? Int(newValue!)! : self.dest }
    }
    var readRegs: [String]? {
        get {
            if mnemonic == .addi {
                return [opA.toReg]
            } else {
                return [opA, opB].map { $0.toReg }
            }
        }
        set {
            if let readRegs = newValue {
                if mnemonic == .addi {
                    opA = readRegs[0].regToNum
                } else {
                    opA = readRegs[0].regToNum
                    opB = readRegs[1].regToNum
                }
            }
        }
    }
    
    let mnemonic: ArithmeticInstructionType
    var dest: Int
    var opA: Int
    var opB: Int // or immediate
}

enum ArithmeticInstructionType: String {
    case add
    case addi
    case sub
    // includes mulu but is executed in Mult unit not ALU
    case mulu
}

struct MemoryInstruction: Instruction {
    var print: String {
        "\(mnemonic.rawValue) \(destOrSource.toReg), \(imm)(\(loadStoreAddr.toReg))"
    }
    var addr: Int
    var name: String {
        mnemonic.rawValue
    }
    var destReg: String? {
        get { mnemonic == .ld ? destOrSource.toReg : nil }
        set { self.destOrSource = mnemonic == .ld ? (newValue != nil ? Int(newValue!)! : self.destOrSource) : self.destOrSource }
    }
    var readRegs: [String]? {
        get {
            let forBoth = [(imm + loadStoreAddr).toReg]
            if mnemonic == .st {
                return [destOrSource.toReg] + forBoth
            } else {
                return forBoth
            }
        }
        set {
            if let readRegs = newValue {
                if mnemonic == .st {
                    // TODO: what about immediate????
                    assert(readRegs.count == 2, "[dest, storeaddr]")
                    destOrSource = readRegs[0].regToNum
                    loadStoreAddr = readRegs[1].regToNum
                } else {
                    // TODO: what about immediate????
                    assert(readRegs.count == 1, "[storeaddr]")
                    loadStoreAddr = readRegs[0].regToNum
                }
            }
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
    var print: String {
        "\(type.rawValue) \(loopStart)"
    }
    var addr: Int
    var name: String {
        type.rawValue
    }
    var destReg: String? {
        get { nil }
        set {}
    }
    var readRegs: [String]? {
        get { nil }
        set {}
    }
    
    let type: LoopInstructionType
    var loopStart: Int
}

enum LoopInstructionType: String {
    case loop
    case loop_pip = "loop.pip"
}

struct NoOp: Instruction {
    var print: String {
        name
    }
    var addr: Int
    var name: String {
        "noop"
    }
    var destReg: String? {
        get { nil }
        set {}
    }
    var readRegs: [String]? {
        get { nil }
        set {}
    }
}

struct MoveInstruction: Instruction {
    // Dest reg representation of LC/EC
    static let LC = -1
    static let EC = -2
    
    var print: String {
        var arg2: String!
        switch type {
        case .setPredicateReg:
            arg2 = val == 0 ? "false" : "true"
        case .setSpecialRegWithImmediate, .setDestRegWithImmediate:
            arg2 = "\(val)"
        case .setDestRegWithSourceReg:
            arg2 = val.toReg
        }
        return "\(name) \(destReg!), \(arg2!)"
    }
    var addr: Int
    var name: String {
        "mov"
    }
    /// -1 for LC, -2 for EC
    var destReg: String? {
        get { reg == MoveInstruction.LC ? "LC" : (reg == MoveInstruction.EC ? "EC" : reg.toReg) }
        set { reg = reg == -1 || reg == -2 ? reg : (newValue != nil ? Int(newValue!) ?? newValue!.regToNum : self.reg) }
    }
    var readRegs: [String]? {
        get { type == .setDestRegWithSourceReg ? [val.toReg] : nil }
        set {
            if type == .setDestRegWithSourceReg {
                assert(newValue?.count == 1)
                val = newValue![0].regToNum
            }
        }
    }
    
    let type: MoveInstructionType
    var reg: Int
    // bool, imm, or source
    var val: Int
}

enum MoveInstructionType: Equatable {
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
    var regToNum: Int {
        if self.first == "x" {
            return Int(dropFirst())!
        } else {
            return Int(self)!
        }
    }
}

extension Sequence where Element == String {
    var regsToAddresses: [Int] {
        self.map { $0.regToNum }
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
