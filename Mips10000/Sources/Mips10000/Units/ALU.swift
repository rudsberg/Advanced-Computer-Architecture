//
//  File.swift
//  
//
//  Created by Joel Rudsberg on 2022-04-03.
//

import Foundation

struct ALU {
    /// The number identifiying the ALU
    let id: Int
    
    /// Item in pipeline register
    private var currentInstruction: ALUItem? = nil
    
    public init(id: Int) {
        self.id = id
    }
    
    enum ALUError: Error {
        case divisionByZero
    }
    
    /// Starts executing 'newInstruction' and returns instruction from last cycle if any
    mutating func execute(newInstruction instruction: ALUItem?) -> ALUItem? {
        guard !(instruction == nil && currentInstruction == nil) else {
            return nil
        }
        
        print("ALU\(id) - \(instruction != nil ? "processing instruction with PC \(instruction!.iq.PC) |" : "") \(currentInstruction != nil ? "outputs instruction with PC \(currentInstruction!.iq.PC)" : "")")
        
        let instrToReturn = currentInstruction
        
        // Save new instruction to pipeline register
        if let instrToProcess = instruction {
            currentInstruction = instrToProcess
            if let computedRes = compute(instruction: instrToProcess.iq) {
                currentInstruction?.computedValue = computedRes
            } else {
                currentInstruction?.exception = true
            }
        }
                
        // If a previous instruction was processed, return it
        if let instrToReturn = instrToReturn {
            if (instruction == nil) {
                currentInstruction = nil
            }
            return instrToReturn
        } else {
            return nil
        }
    }
    
    private func compute(instruction: IntegerQueueItem) -> Int? {
        switch(InstructionType(rawValue: instruction.OpCode)!) {
        case .add, .addi:
            return instruction.OpAValue + instruction.OpBValue
        case .sub:
            return instruction.OpAValue - instruction.OpBValue
        case .mulu:
            return instruction.OpAValue * instruction.OpBValue
        case .divu:
            if (instruction.OpBValue == 0) {
                return nil
            } else {
                return instruction.OpAValue / instruction.OpBValue
            }
        case .remu:
            return instruction.OpAValue % instruction.OpBValue
        }
    }
}
