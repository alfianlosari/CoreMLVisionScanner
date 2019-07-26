//
//  Model.swift
//  VisionScannerDataDetector
//
//  Created by Alfian Losari on 26/07/19.
//  Copyright © 2019 Alfian Losari. All rights reserved.
//

import UIKit

extension UISegmentedControl {
    
    var scanOption: ScanOption {
        return ScanOption(rawValue: selectedSegmentIndex)!
    }
    
}

typealias ColoredBoxGroup = (color: CGColor, boxes: [CGRect])


struct ScanResult {
    let scanOption: ScanOption
    let results: [String]
    let rectBoxes: [CGRect]
}


enum ScanOption: Int {
    case ocr
    case url
    case tel
    case date
    case cat
    case dog
    case human
}

enum Item: Hashable {
    static func == (lhs: Item, rhs: Item) -> Bool {
        switch (lhs, rhs) {
            
        case (.empty, .empty):
            return true
            
            
        case (.segmentedOptions, .segmentedOptions):
            return true
            
        case (.result(let text), .result(let text2)):
            return text == text2
            
        default: return false
            
        }
        
    }
    
    case empty
    
    case segmentedOptions
    case result(String)
    
    func hash(into hasher: inout Hasher) {
        switch self {
            
        case .empty:
            hasher.combine("empty")
            
            
        case .segmentedOptions:
            hasher.combine("segment_option")
            
        case .result(let text):
            hasher.combine("result_\(UUID().uuidString)\(text)")
            
            
            
        }
        
        
    }
    
}
