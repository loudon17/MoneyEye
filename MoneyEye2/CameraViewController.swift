//
//  CameraViewController.swift
//  MoneyEye2
//
//  Created by Luigi Donnino on 18/11/24.
//
import UIKit
import AVFoundation
import Vision
import AudioToolbox

class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    private var bufferSize: CGSize = .zero
    private var rootLayer: CALayer! = nil
    private var detectionOverlay: CALayer! = nil
    private var requests = [VNRequest]()
    
    private var detectionTimestamps: [String: Date] = [:] // Stores the timestamp for each detected class
    
    private let session = AVCaptureSession()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutputQueue")
    
    private var isDisplayingClassName = false // Flag to control the class name screen
    
    private var circularFrameLayer: CAShapeLayer! // Circular frame layer
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupAVCapture()
        setupVision()
        setupCircularFrame() // Set up the circular frame
    }
    
    func setupAVCapture() {
        var deviceInput: AVCaptureDeviceInput!
        
        // Select a video device and create an input.
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            fatalError("No video camera available")
        }
        do {
            deviceInput = try AVCaptureDeviceInput(device: videoDevice)
        } catch {
            fatalError("Could not create video device input: \(error)")
        }
        
        session.beginConfiguration()
        session.sessionPreset = .vga640x480 // Match the model's image size.
        
        // Add video input.
        guard session.canAddInput(deviceInput) else {
            fatalError("Could not add video device input to the session")
        }
        session.addInput(deviceInput)
        
        // Add video output.
        guard session.canAddOutput(videoDataOutput) else {
            fatalError("Could not add video output to the session")
        }
        session.addOutput(videoDataOutput)
        
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        
        let captureConnection = videoDataOutput.connection(with: .video)
        captureConnection?.isEnabled = true
        
        // Set the buffer size.
        let dimensions = CMVideoFormatDescriptionGetDimensions(videoDevice.activeFormat.formatDescription)
        bufferSize = CGSize(width: CGFloat(dimensions.width), height: CGFloat(dimensions.height))
        
        session.commitConfiguration()
        
        // Set up the preview layer.
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        rootLayer = view.layer
        rootLayer.addSublayer(previewLayer)
        previewLayer.frame = rootLayer.bounds
        
        // Start the session.
        session.startRunning()
    }
    
    func setupCircularFrame() {
        // Calculate the size and position of the circular frame
        let frameDiameter: CGFloat = 300 // Adjust the diameter as needed
        let frameRadius = frameDiameter / 2
        let frameCenter = CGPoint(x: rootLayer.bounds.midX, y: rootLayer.bounds.midY)
        
        // Create a circular path
        let circularPath = UIBezierPath(arcCenter: frameCenter, radius: frameRadius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        
        // Create a CAShapeLayer to display the circular frame
        circularFrameLayer = CAShapeLayer()
        circularFrameLayer.path = circularPath.cgPath
        circularFrameLayer.strokeColor = UIColor.white.cgColor // Circular frame color
        circularFrameLayer.fillColor = UIColor.clear.cgColor // No fill color
        circularFrameLayer.lineWidth = 8.0 // Width of the circular border
        rootLayer.addSublayer(circularFrameLayer) // Add to the root layer
    }
    
    func setupVision() {
        // Load the Core ML model.
        guard let modelURL = Bundle.main.url(forResource: "MultiNoteClassifier", withExtension: "mlmodelc"),
              let visionModel = try? VNCoreMLModel(for: MLModel(contentsOf: modelURL)) else {
            fatalError("Could not load model")
        }
        
        // Create a Vision request.
        let objectRecognition = VNCoreMLRequest(model: visionModel) { (request, error) in
            DispatchQueue.main.async {
                guard let results = request.results else { return }
                self.handleVisionResults(results)
            }
        }
        requests = [objectRecognition]
        
        // Set up the detection overlay.
        setupDetectionOverlay()
    }
    
    func setupDetectionOverlay() {
        detectionOverlay = CALayer()
        detectionOverlay.bounds = CGRect(x: 0, y: 0, width: bufferSize.width, height: bufferSize.height)
        detectionOverlay.position = CGPoint(x: rootLayer.bounds.midX, y: rootLayer.bounds.midY)
        detectionOverlay.setAffineTransform(CGAffineTransform(rotationAngle: .pi / 2).scaledBy(x: 1, y: -1))
        rootLayer.addSublayer(detectionOverlay)
    }
    
    func handleVisionResults(_ results: [Any]) {
        detectionOverlay.sublayers = nil // Clear previous detections.
        
        let currentTimestamp = Date() // Current time for timestamp tracking
        
        for result in results where result is VNRecognizedObjectObservation {
            guard let objectObservation = result as? VNRecognizedObjectObservation else { continue }
            
            // Get the top label.
            let topLabel = objectObservation.labels.first!
            let labelText = topLabel.identifier
            let bounds = VNImageRectForNormalizedRect(objectObservation.boundingBox, Int(bufferSize.width), Int(bufferSize.height))
            
            // Track detection timestamp.
            if let firstDetectedTime = detectionTimestamps[labelText] {
                // Check if the object has been detected for over 5 seconds
                if currentTimestamp.timeIntervalSince(firstDetectedTime) > 5 && !isDisplayingClassName {
                    triggerFeedback(for: labelText) // Trigger vibration
                    displayClassNameScreen(for: labelText) // Display class name screen
                }
            } else {
                // Save the timestamp of the first detection
                detectionTimestamps[labelText] = currentTimestamp
            }
            
            // Create a bounding box layer.
            let shapeLayer = createBoundingBoxLayer(bounds: bounds, label: labelText, confidence: topLabel.confidence)
            detectionOverlay.addSublayer(shapeLayer)
        }
        
        // Remove stale detections from the tracking dictionary
        cleanupOldDetections(currentTimestamp: currentTimestamp)
    }
    
    func cleanupOldDetections(currentTimestamp: Date) {
        // Remove classes that haven't been seen for a while
        detectionTimestamps = detectionTimestamps.filter { _, timestamp in
            currentTimestamp.timeIntervalSince(timestamp) < 5
        }
    }
    
    func createBoundingBoxLayer(bounds: CGRect, label: String, confidence: VNConfidence) -> CALayer {
        let shapeLayer = CALayer()
        shapeLayer.bounds = bounds
        shapeLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        shapeLayer.backgroundColor = CGColor(red: 1, green: 1, blue: 0, alpha: 0.4)
        shapeLayer.cornerRadius = 4.0

        // Create and configure the text layer.
        let textLayer = CATextLayer()
        textLayer.string = "\(label)\nConfidence: \(String(format: "%.2f", (confidence*100)))"
        textLayer.fontSize = 32 // Larger font size for better visibility
        textLayer.font = UIFont.boldSystemFont(ofSize: 32) // Bold font
        textLayer.foregroundColor = UIColor.black.cgColor
        textLayer.alignmentMode = .center
        textLayer.contentsScale = UIScreen.main.scale // Ensure sharp rendering

        // Position the text layer within the bounds of the bounding box.
        textLayer.bounds = CGRect(x: 0, y: 0, width: bounds.height - 4, height: bounds.width - 4)
        textLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)

        // Fix text orientation for landscape and mirroring issues.
        textLayer.setAffineTransform(
            CGAffineTransform(rotationAngle: CGFloat(3.1412 / 2))
            .scaledBy(x: 1.0, y: -1.0) // Correct mirrored text
        )

        shapeLayer.addSublayer(textLayer)
        return shapeLayer
    }
    
    func triggerFeedback(for label: String) {
        // Ensure the feedback is triggered only once per detection
        detectionTimestamps.removeValue(forKey: label)
        
        // Vibration immediately
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        
        // Delay for 0.5 seconds before displaying the class name screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.displayClassNameScreen(for: label) // Show class name after a slight delay
        }
    }
    
    func displayClassNameScreen(for label: String) {
        // Set flag to stop scanning
        isDisplayingClassName = true
        
        // Modify label names for specific cases
        let correctedLabel = correctedLabelName(for: label)
        
        // Create a full screen label
        let labelText = UILabel()
        labelText.text = correctedLabel
        labelText.font = UIFont.boldSystemFont(ofSize: 55)
        labelText.textColor = .red
        labelText.textAlignment = .center
        labelText.frame = rootLayer.bounds
        labelText.backgroundColor = .white
        view.addSubview(labelText)
        
        // Remove the label after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            labelText.removeFromSuperview()
            self.isDisplayingClassName = false
        }
    }
    
    func correctedLabelName(for label: String) -> String {
        // Map the specific labels to corrected names 5 10 20 50 100 / 10 100 20 200 5 50
        switch label {
        case "1 dolar":
            return "1 Dollar"
        case "5 dolar":
            return "5 Dollars"
        case "10 dolar":
            return "10 Dollars"
        case "20 dolar":
            return "20 Dollars"
        case "50 dolar":
            return "50 Dollar"
        case "100 dolar":
            return "100 Dollars"
        case "10 TL":
            return "10 Turkish Liras"
        case "100 TL":
            return "100 Turkish Liras"
        case "20 TL":
            return "20 Turkish Liras"
        case "200 TL":
            return "200 Turkish Liras"
        case "5 TL":
            return "5 Turkish Liras"
        case "50 TL":
            return "50 Turkish Liras"
            
        default:
            return label // No change for other labels
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try requestHandler.perform(requests)
        } catch {
            print("Error performing Vision request: \(error)")
        }
    }
}

