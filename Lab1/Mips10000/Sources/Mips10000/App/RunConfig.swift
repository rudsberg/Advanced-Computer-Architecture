//
//  File.swift
//  
//
//  Created by Joel Rudsberg on 2022-04-09.
//

import Foundation

struct RunConfig {
    typealias Cycle = Int
    let programFile: String
    let logFile: String
    var runUpToCycle: Cycle? = nil
}
