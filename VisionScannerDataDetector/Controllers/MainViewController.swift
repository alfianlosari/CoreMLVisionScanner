//
//  ViewController.swift
//  VisionScannerDataDetector
//
//  Created by Alfian Losari on 25/07/19.
//  Copyright © 2019 Alfian Losari. All rights reserved.
//

import UIKit
import Vision
import VisionKit

class MainViewController: UITableViewController {
    
    @IBOutlet weak var imageView: UIImageView!
    var pathLayer: CALayer?
    var imageWidth: CGFloat = 0
    var imageHeight: CGFloat = 0
    
    private var requests = [VNRequest]()
    private let textRecognitionWorkQueue = DispatchQueue(label: "TextRecognitionQueue",
                                                         qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    
    var dataSource: UITableViewDiffableDataSource<Int, Item>?
    
    var scanOption: ScanOption = .ocr {
        didSet {
            for cell in tableView.visibleCells {
                if let segmentedCell = cell as? SegmentedTableViewCell {
                    segmentedCell.segmentedControl.selectedSegmentIndex = self.scanOption.rawValue
                }
            }
            self.buildData()
        }
    }
    
    lazy var animalDetectionReqeust: VNDetectAnimalRectanglesRequest = {
        let req = VNDetectAnimalRectanglesRequest(completionHandler: self.handleDetectedAnimals)
        return req
        
    }()
    
    var items: [Item] = [
        .empty
    ]
    
    var image: UIImage? {
        didSet {
            self.scanOption = .ocr
            self.results = nil
            self.buildData()
        }
    }
    
    var results: [ScanResult]? {
        didSet {
            self.buildData()
        }
    }
    
    func buildData() {
        self.buildItems()
        let snapshot = self.createSnapshot()
        self.dataSource?.apply(snapshot, animatingDifferences: false)
    }
    
    func buildItems() {
        if let image = image {
            var _items = [Item]()
            _items.append(.segmentedOptions)
            pathLayer?.removeFromSuperlayer()
            pathLayer = nil
            
            if let results = results {
                if let opt = results.first(where:{ $0.scanOption == self.scanOption }) {
                    let texts = opt.results.map { Item.result($0) }
                    
                    self.show(image)
                    self.draw(textBoxes: opt.rectBoxes, onImageWithBounds: self.pathLayer!.bounds)
                    
                    self.pathLayer!.setNeedsDisplay()
                    
                    _items.append(contentsOf: texts)
                }
            }
            self.items = _items
        }
    }
    
    func createSnapshot() -> NSDiffableDataSourceSnapshot<Int, Item> {
        let snapshot = NSDiffableDataSourceSnapshot<Int, Item>()
        let sectionIndex = 0
        snapshot.appendSections([sectionIndex])
        snapshot.appendItems(self.items, toSection: sectionIndex)
        return snapshot
    }
    
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupVision()
        configureTableView()
        configureDataSource()
    }
    
    private func configureTableView() {
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        self.tableView.tableFooterView = UIView()
    }
    
    
    func configureDataSource() {
        dataSource = UITableViewDiffableDataSource<Int, Item>(tableView: tableView, cellProvider: { (tableView, indexPath, item) -> UITableViewCell? in
            
            switch item {
            case .empty:
                let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
                cell.textLabel?.numberOfLines = 0
                cell.textLabel?.text = "Please take a picture of your document by tapping the scan button"
                return cell
            case .segmentedOptions:
                let cell = tableView.dequeueReusableCell(withIdentifier: "SegmentCell", for: indexPath) as! SegmentedTableViewCell
                cell.segmentedControl.selectedSegmentIndex = self.scanOption.rawValue
                cell.delegate = self
                return cell
                
            case .result(let text):
                let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
                cell.textLabel?.numberOfLines = 0
                cell.textLabel?.text = text
                return cell
            }
        })
        
        let snapshot = self.createSnapshot()
        self.dataSource?.apply(snapshot, animatingDifferences: false)
    }
    
    
    
    @IBAction func scanTapped(_ sender: UIControl?) {
        let documentCameraViewController = VNDocumentCameraViewController()
        documentCameraViewController.delegate = self
        present(documentCameraViewController, animated: true)
    }
}

// MARK: SEGMENT CELL DELEGATE

extension MainViewController: SegmentedTableViewCellDelegate {
    
    func segmentedTableViewCell(_ cell: SegmentedTableViewCell, didSelectAt index: Int) {
        if let option = ScanOption(rawValue: index) {
            self.scanOption = option
        }
    }
}


// MARK: VISION

extension MainViewController {
    
    private func setupVision() {
        let textRecognitionRequest = VNRecognizeTextRequest { (request, error) in
            
            var phoneNumbers: [String] = []
            var urls: [String] = []
            var dates: [String] = []
            var urlBoxes = [CGRect]()
            var phoneBoxes = [CGRect]()
            var datesBoxes = [CGRect]()
            
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                print("The observations are of an unexpected type.")
                return
            }
            
            let ocrBoxes = observations.map {
                $0.boundingBox
            }
            
            let maximumCandidates = 1
            var ocrText = ""
            
            for observation in observations {
                guard let candidate = observation.topCandidates(maximumCandidates).first else { continue }
                let text = candidate.string
                ocrText += text
                ocrText += "\n"
                
                do {
                    let detector = try NSDataDetector(types: NSTextCheckingAllTypes)
                    let matches = detector.matches(in: candidate.string, options: .init(), range: NSRange(location: 0, length: candidate.string.count))
                    for match in matches {
                        let matchStartIdx = text.index(text.startIndex, offsetBy: match.range.location)
                        let matchEndIdx = text.index(text.startIndex, offsetBy: match.range.location + match.range.length)
                        let matchedString = String(text[matchStartIdx..<matchEndIdx])
                        
                        
                        switch match.resultType {
                            
                        case .phoneNumber:
                            phoneNumbers.append(matchedString)
                            phoneBoxes.append(observation.boundingBox)
                            
                            
                        case .link:
                            
                            urls.append(match.url?.absoluteString ?? "")
                            urlBoxes.append(observation.boundingBox)
                            
                        case .date:
                            if let date = match.date {
                                dates.append("\(date)")
                            }
                            
                            if let timezone = match.timeZone {
                                dates.append(timezone.abbreviation() ?? "")
                            }
                            
                            if match.duration > 0 {
                                dates.append("\(match.duration)")
                            }
                            datesBoxes.append(observation.boundingBox)
                            
                            
                        default:
                            print("\(matchedString) type:\(match.resultType)")
                        }
                    }
                    
                } catch {
                    print(error)
                }
                
            }
            
            
            self.results?.append(contentsOf: [
                ScanResult(scanOption: .ocr, results: [ocrText], rectBoxes: ocrBoxes),
                ScanResult(scanOption: .url, results: urls, rectBoxes: urlBoxes),
                ScanResult(scanOption: .tel, results: phoneNumbers, rectBoxes: phoneBoxes),
                ScanResult(scanOption: .date, results: dates, rectBoxes: datesBoxes)
            ])
        }
        
        textRecognitionRequest.recognitionLevel = .accurate
        self.requests = [textRecognitionRequest, animalDetectionReqeust]
    }
    
    
    fileprivate func handleDetectedHumans(request: VNRequest?, error: Error?) {
        if let _ = error as NSError? {
            return
        }
        
        DispatchQueue.main.async {
            guard let results = request?.results as? [VNRecognizedObjectObservation] else {
                return
            }
            
            var count: Int = 0
            var boxes: [CGRect] = []
            
            for result in results {
                count += 1
                boxes.append(result.boundingBox)
                
            }
            self.results?.append(contentsOf: [
                ScanResult(scanOption: .human, results: ["Found \(count) humans"], rectBoxes: boxes)
            ])
        }
    }
    
    fileprivate func handleDetectedAnimals(request: VNRequest?, error: Error?) {
        if let _ = error as NSError? {
            return
        }
        
        DispatchQueue.main.async {
            guard let results = request?.results as? [VNRecognizedObjectObservation] else {
                return
            }
            
            var catCount: Int = 0
            var dogCount: Int = 0
            var catBoxes: [CGRect] = []
            var dogBoxes: [CGRect] = []
            
            for result in results {
                for label in result.labels {
                    if label.identifier.lowercased() == "cat" {
                        catCount += 1
                        catBoxes.append(result.boundingBox)
                    } else if label.identifier.lowercased() == "dog" {
                        dogCount += 1
                        dogBoxes.append(result.boundingBox)
                    }
                }
            }
            
            self.results?.append(contentsOf: [
                ScanResult(scanOption: .dog, results: ["Found \(dogCount) dogs"], rectBoxes: dogBoxes),
                ScanResult(scanOption: .cat, results: ["Found \(catCount) cats"], rectBoxes: catBoxes),
                ])
        }
    }
}


// MARK: DRAWING

extension MainViewController {
    
    func show(_ image: UIImage) {
        // Remove previous paths & image
        pathLayer?.removeFromSuperlayer()
        pathLayer = nil
        imageView.image = nil
        
        // Account for image orientation by transforming view.
        let correctedImage = scaleAndOrient(image: image)
        
        // Place photo inside imageView.
        imageView.image = correctedImage
        
        // Transform image to fit screen.
        guard let cgImage = correctedImage.cgImage else {
            print("Trying to show an image not backed by CGImage!")
            return
        }
        
        let fullImageWidth = CGFloat(cgImage.width)
        let fullImageHeight = CGFloat(cgImage.height)
        
        let imageFrame = imageView.frame
        let widthRatio = fullImageWidth / imageFrame.width
        let heightRatio = fullImageHeight / imageFrame.height
        
        // ScaleAspectFit: The image will be scaled down according to the stricter dimension.
        let scaleDownRatio = max(widthRatio, heightRatio)
        
        // Cache image dimensions to reference when drawing CALayer paths.
        imageWidth = fullImageWidth / scaleDownRatio
        imageHeight = fullImageHeight / scaleDownRatio
        
        // Prepare pathLayer to hold Vision results.
        let xLayer = (imageFrame.width - imageWidth) / 2
        let yLayer = imageView.frame.minY + (imageFrame.height - imageHeight) / 2
        let drawingLayer = CALayer()
        drawingLayer.bounds = CGRect(x: xLayer, y: yLayer, width: imageWidth, height: imageHeight)
        drawingLayer.anchorPoint = CGPoint.zero
        drawingLayer.position = CGPoint(x: xLayer, y: yLayer)
        drawingLayer.opacity = 0.5
        pathLayer = drawingLayer
        self.view.layer.addSublayer(pathLayer!)
    }
    
    func scaleAndOrient(image: UIImage) -> UIImage {
        
        // Set a default value for limiting image size.
        let maxResolution: CGFloat = 640
        
        guard let cgImage = image.cgImage else {
            print("UIImage has no CGImage backing it!")
            return image
        }
        
        // Compute parameters for transform.
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        var transform = CGAffineTransform.identity
        
        var bounds = CGRect(x: 0, y: 0, width: width, height: height)
        
        if width > maxResolution ||
            height > maxResolution {
            let ratio = width / height
            if width > height {
                bounds.size.width = maxResolution
                bounds.size.height = round(maxResolution / ratio)
            } else {
                bounds.size.width = round(maxResolution * ratio)
                bounds.size.height = maxResolution
            }
        }
        
        let scaleRatio = bounds.size.width / width
        let orientation = image.imageOrientation
        switch orientation {
        case .up:
            transform = .identity
        case .down:
            transform = CGAffineTransform(translationX: width, y: height).rotated(by: .pi)
        case .left:
            let boundsHeight = bounds.size.height
            bounds.size.height = bounds.size.width
            bounds.size.width = boundsHeight
            transform = CGAffineTransform(translationX: 0, y: width).rotated(by: 3.0 * .pi / 2.0)
        case .right:
            let boundsHeight = bounds.size.height
            bounds.size.height = bounds.size.width
            bounds.size.width = boundsHeight
            transform = CGAffineTransform(translationX: height, y: 0).rotated(by: .pi / 2.0)
        case .upMirrored:
            transform = CGAffineTransform(translationX: width, y: 0).scaledBy(x: -1, y: 1)
        case .downMirrored:
            transform = CGAffineTransform(translationX: 0, y: height).scaledBy(x: 1, y: -1)
        case .leftMirrored:
            let boundsHeight = bounds.size.height
            bounds.size.height = bounds.size.width
            bounds.size.width = boundsHeight
            transform = CGAffineTransform(translationX: height, y: width).scaledBy(x: -1, y: 1).rotated(by: 3.0 * .pi / 2.0)
        case .rightMirrored:
            let boundsHeight = bounds.size.height
            bounds.size.height = bounds.size.width
            bounds.size.width = boundsHeight
            transform = CGAffineTransform(scaleX: -1, y: 1).rotated(by: .pi / 2.0)
        default:
            break
        }
        
        return UIGraphicsImageRenderer(size: bounds.size).image { rendererContext in
            let context = rendererContext.cgContext
            
            if orientation == .right || orientation == .left {
                context.scaleBy(x: -scaleRatio, y: scaleRatio)
                context.translateBy(x: -height, y: 0)
            } else {
                context.scaleBy(x: scaleRatio, y: -scaleRatio)
                context.translateBy(x: 0, y: -height)
            }
            context.concatenate(transform)
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
    }
}

// MARK: VNDocumentCameraViewControllerDelegate

extension MainViewController: VNDocumentCameraViewControllerDelegate {
    
    public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        
        controller.dismiss(animated: true)
        
        if scan.pageCount > 0 {
            let image = scan.imageOfPage(at: 0)
            
            self.image = image
            show(image)
            self.results = []
            if let cgImage = image.cgImage {
                let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try requestHandler.perform(self.requests)
                } catch {
                    print(error)
                }
            }
        }
    }
    
    fileprivate func draw(textBoxes: [CGRect], onImageWithBounds bounds: CGRect) {
        CATransaction.begin()
        for rect in textBoxes {
            let wordBox = boundingBox(forRegionOfInterest: rect, withinImageBounds: bounds)
            
            let wordLayer = shapeLayer(color: .red, frame: wordBox)
            
            // Add to pathLayer on top of image.
            pathLayer?.addSublayer(wordLayer)
            
            
        }
        CATransaction.commit()
    }
    
    fileprivate func boundingBox(forRegionOfInterest: CGRect, withinImageBounds bounds: CGRect) -> CGRect {
        
        let imageWidth = bounds.width
        let imageHeight = bounds.height
        
        // Begin with input rect.
        var rect = forRegionOfInterest
        
        // Reposition origin.
        rect.origin.x *= imageWidth
        rect.origin.x += bounds.origin.x
        rect.origin.y = (1 - rect.origin.y) * imageHeight + bounds.origin.y
        
        // Rescale normalized coordinates.
        rect.size.width *= imageWidth
        rect.size.height *= imageHeight
        
        return rect
    }
    
    fileprivate func shapeLayer(color: UIColor, frame: CGRect) -> CAShapeLayer {
        // Create a new layer.
        let layer = CAShapeLayer()
        
        // Configure layer's appearance.
        layer.fillColor = nil // No fill to show boxed object
        layer.shadowOpacity = 0
        layer.shadowRadius = 0
        layer.borderWidth = 2
        
        // Vary the line color according to input.
        layer.borderColor = color.cgColor
        
        // Locate the layer.
        layer.anchorPoint = .zero
        layer.frame = frame
        layer.masksToBounds = true
        
        // Transform the layer to have same coordinate system as the imageView underneath it.
        layer.transform = CATransform3DMakeScale(1, -1, 1)
        
        return layer
    }
}
