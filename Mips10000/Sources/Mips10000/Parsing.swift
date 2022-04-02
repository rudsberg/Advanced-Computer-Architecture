//
//  File.swift
//  
//
//  Created by Joel Rudsberg on 2022-04-02.
//

import Foundation

public struct Parser {
    func parseInstructions(fromFile file: String) throws -> [Instruction] {
        // Load json and parse as an array of strings
        let instructionStrings = try intructionStrings(fromFile: file)
         
        // Map strings to instructions
        var pc = -1 // TODO: not hexadeciamal?
        return instructionStrings.map { i -> (String, Int, Int, Int) in
            print(i)
            let parts = Array(i.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "x", with: "").split(separator: " "))
            print(parts)
            return (String(parts[0]), Int(parts[1])!, Int(parts[2])!, Int(parts[3])!)
        }.map { (type, dest, arg1, arg2) in
            pc += 1
            switch (type) {
            case "add":
                return Instruction(address: pc, type: .add(dest, arg1, arg2))
            case "addi":
                return Instruction(address: pc, type: .addi(dest, arg1, arg2))
            case "sub":
                return Instruction(address: pc, type: .sub(dest, arg1, arg2))
            case "mulu":
                return Instruction(address: pc, type: .mulu(dest, arg1, arg2))
            case "divu":
                return Instruction(address: pc, type: .divu(dest, arg1, arg2))
            case "remu":
                return Instruction(address: pc, type: .remu(dest, arg1, arg2))
            default:
                fatalError("Non-supported instruction")
            }
        }
    }
    
    private func intructionStrings(fromFile file: String) throws -> [String] {
        let loader = FileIOController()
        return try loader.read([String].self, documentName: file)
    }
}
