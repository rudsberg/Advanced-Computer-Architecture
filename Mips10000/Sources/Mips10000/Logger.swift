//
//  File.swift
//  
//
//  Created by Joel Rudsberg on 2022-04-02.
//

import Foundation

struct Logger {    
    func updateLog(with state: State, documentName: String, deleteExistingFile: Bool = false) throws {
        let fileIO = FileIOController()
        
        if (fileIO.fileExist(documentName: documentName) && !deleteExistingFile) {
            // Get current state, append current state and write update
            var newState = try fileIO.read([State].self, documentName: documentName)
            newState.append(state)
            try fileIO.write(newState, toDocumentNamed: documentName)
        } else {
            // Create file and write current state
            fileIO.createFile(documentName: documentName)
            try fileIO.write([state], toDocumentNamed: documentName)
        }
    }
}


