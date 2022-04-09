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
        var pc = -1 
        return instructionStrings.map { i -> (String, Int, Int, Int) in
            let parts = Array(i.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "x", with: "").split(separator: " "))
            return (String(parts[0]), Int(parts[1])!, Int(parts[2])!, Int(parts[3])!)
        }.map { (type, dest, opA, opB) in
            pc += 1
            return Instruction(pc: pc, dest: dest, opA: opA, opB: opB, type: .init(rawValue: type)!)
        }
    }
    
    private func intructionStrings(fromFile file: String) throws -> [String] {
        let loader = FileIOController.shared
        return try loader.read([String].self, documentName: file)
    }
}
