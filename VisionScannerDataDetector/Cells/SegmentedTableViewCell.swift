//
//  SegmentedTableViewCell.swift
//  VisionScannerDataDetector
//
//  Created by Alfian Losari on 25/07/19.
//  Copyright © 2019 Alfian Losari. All rights reserved.
//

import UIKit

protocol SegmentedTableViewCellDelegate: class {
    
    func segmentedTableViewCell(_ cell: SegmentedTableViewCell, didSelectAt index: Int)
}


class SegmentedTableViewCell: UITableViewCell {

    @IBOutlet weak var segmentedControl: UISegmentedControl!
    weak var delegate: SegmentedTableViewCellDelegate?
    
    
    @IBAction func segmentChanged(_ sender: UISegmentedControl) {
        self.delegate?.segmentedTableViewCell(self, didSelectAt: sender.selectedSegmentIndex)
        
    }
   
}
