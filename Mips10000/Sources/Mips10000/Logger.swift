//
//  File.swift
//  
//
//  Created by Joel Rudsberg on 2022-04-02.
//

import Foundation

struct Logger {    
    func updateLog(documentName: String) throws {
        let fileIO = FileIOController()
        if (fileIO.fileExist(documentName: documentName)) {
            // Get current state, append current state and write update
            var state = try fileIO.read([State].self, documentName: documentName)
            state.append(State.shared)
            try fileIO.write(state, toDocumentNamed: documentName)
        } else {
            // Create file and write current state
            fileIO.createFile(documentName: documentName)
            try fileIO.write(State.shared, toDocumentNamed: documentName)
        }
    }
}


