//
//  CameraFaceDetectionService.swift
//  FaceCraft
//
//  Created by Okjoon Kim on 11/27/25.
//

import Foundation
import AVFoundation
import Vision
import UIKit
import ImageIO

/// The engine of the app.
/// It configures the camera, runs Vision algorithms on every frame,
/// and converts the math into something SwiftUI can draw.
final class CameraFaceDetectionService: NSObject {
    
    // MARK: - Public API
    
    /// Callback triggered when faces are detected.
    /// Returns an array of `DetectedFace` structs with coordinates ready for SwiftUI.
    var onFacesDetected: (([DetectedFace]) -> Void)?
    
    let session = AVCaptureSession()
    
    /// The size of the SwiftUI view (e.g., the screen size).
    /// We need this to calculate where to draw the lines relative to the camera frame.
    /// This is updated by the View via the ViewModel.
    var previewViewSize: CGSize = .zero
    
    // MARK: - Private Properties
    
    // Running camera operations on a background queue prevents the UI from stuttering.
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    
    // This output allows us to grab the raw pixel buffer from the camera.
    private let videoOutput = AVCaptureVideoDataOutput()
    
    // A separate queue for Vision processing so we don't block the camera or the UI.
    private let visionQueue = DispatchQueue(label: "camera.vision.queue")
    
    // Throttling variables to control the frame rate of detection
    private var lastRequestTime: CFTimeInterval = 0
    private let minRequestInterval: CFTimeInterval = 0.06 // ~15 FPS limit
    
    override init() {
        super.init()
        configureSession()
    }
    
    func start() {
        sessionQueue.async {
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }
    
    func stop() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }
}

// MARK: - 1. Session Configuration
extension CameraFaceDetectionService {
    
    private func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.session.beginConfiguration()
            self.session.sessionPreset = .high
            
            // Input: Front Camera
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                       for: .video,
                                                       position: .front),
                  let input = try? AVCaptureDeviceInput(device: device)
            else { return }
            
            if self.session.canAddInput(input) {
                self.session.addInput(input)
            }
            
            // Output: Raw Video Data
            self.videoOutput.setSampleBufferDelegate(self, queue: self.visionQueue)
            
            // Important: If Vision is slow, drop frames. Do not backlog.
            self.videoOutput.alwaysDiscardsLateVideoFrames = true
            
            if self.session.canAddOutput(self.videoOutput) {
                self.session.addOutput(self.videoOutput)
            }
            
            // --- CRITICAL CONFIGURATION ---
            // Physical sensors are Landscape. We force the connection to rotate the
            // buffer to Portrait. This simplifies our math later because the
            // image dimensions (e.g., 1080x1920) will match the phone screen's aspect ratio.
            if let conn = self.videoOutput.connection(with: .video),
               conn.isVideoOrientationSupported {
                conn.videoOrientation = .portrait
                
                // Mirror the video so it acts like a selfie mirror
                conn.isVideoMirrored = true
            }
            
            self.session.commitConfiguration()
        }
    }
}

// MARK: - 2. The Vision Loop
extension CameraFaceDetectionService: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    /// Called repeatedly for every video frame (sampleBuffer)
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        
        // A. Throttling
        // Face detection is heavy. We skip frames to keep CPU usage low (~15 FPS).
        let now = CACurrentMediaTime()
        guard now - lastRequestTime > minRequestInterval else { return }
        lastRequestTime = now
        
        // B. Get the Pixels
        // Convert the CMSampleBuffer wrapper into a raw image buffer (CVPixelBuffer)
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // C. Create the Request
        // We define WHAT we want Vision to do (find faces and landmarks)
        let req = VNDetectFaceLandmarksRequest { [weak self] request, error in
            guard let self = self, error == nil else { return }
            self.handleVisionResults(request.results, pixelBuffer: pixelBuffer)
        }
        
        // D. Perform the Request
        // orientation: .up
        // Because we rotated the connection in `configureSession`, the pixel buffer
        // is already physically upright. We don't need to tell Vision to rotate it.
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .up,
            options: [:]
        )
        
        try? handler.perform([req])
    }
    
    /// Processes the raw Vision results into usable UI coordinates
    private func handleVisionResults(_ results: [Any]?, pixelBuffer: CVPixelBuffer) {
        guard let observations = results as? [VNFaceObservation] else { return }
        
        // Dimensions we need for scaling math
        let viewSize = self.previewViewSize
        let imgWidth = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let imgHeight = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        let imgSize = CGSize(width: imgWidth, height: imgHeight)
        
        let faces: [DetectedFace] = observations.compactMap { face in
            
            // --- STEP 1: Process Bounding Box ---
            
            // Vision Bounding Box is normalized (0.0 to 1.0) with origin at BOTTOM-Left.
            let visionBox = face.boundingBox
            
            // We flip Y to match UIKit/SwiftUI (TOP-Left origin).
            // New Y = 1.0 - (originalY + height)
            let normalizedBox = CGRect(
                x: visionBox.origin.x,
                y: 1 - visionBox.origin.y - visionBox.height,
                width: visionBox.width,
                height: visionBox.height
            )
            
            // Convert normalized rect (0-1) to View pixels (e.g. 0-393)
            let bbox = self.convertToViewRect(normalizedBox, imageSize: imgSize, viewSize: viewSize)
            
            // --- STEP 2: Process Landmarks ---
            
            guard let landmarks = face.landmarks else {
                return DetectedFace(boundingBox: bbox, leftEye: [], rightEye: [], mouth: [], nose: [], noseCrest: [], faceContour: [])
            }
            
            // Helper function to convert a specific region (like an eye)
            func convertRegion(_ region: VNFaceLandmarkRegion2D?) -> [CGPoint] {
                guard let region = region else { return [] }
                
                return region.normalizedPoints.map { point in
                    // `point` is normalized relative to the FACE bounding box, not the whole image.
                    let lx = point.x
                    let ly = point.y
                    
                    // 1. Convert to Global Vision Coordinates (0-1 relative to image)
                    let visionX = visionBox.origin.x + lx * visionBox.width
                    let visionY = visionBox.origin.y + ly * visionBox.height
                    
                    // 2. Flip Y (Vision Bottom-Left -> UIKit Top-Left)
                    let normalizedPoint = CGPoint(x: visionX, y: 1 - visionY)
                    
                    // 3. Scale to View Pixels (Aspect Fill)
                    return self.convertToViewPoint(normalizedPoint, imageSize: imgSize, viewSize: viewSize)
                }
            }
            
            return DetectedFace(
                boundingBox: bbox,
                leftEye: convertRegion(landmarks.leftEye),
                rightEye: convertRegion(landmarks.rightEye),
                mouth: convertRegion(landmarks.outerLips),
                nose: convertRegion(landmarks.nose),
                noseCrest: convertRegion(landmarks.noseCrest),
                faceContour: convertRegion(landmarks.faceContour)
            )
        }
        
        // Dispatch to Main Thread because this data drives the UI
        DispatchQueue.main.async { [weak self] in
            self?.onFacesDetected?(faces)
        }
    }
}

// MARK: - 3. Aspect Fill Math
extension CameraFaceDetectionService {
    
    // Converts a normalized rect (0-1) to screen pixels, accounting for "Aspect Fill" cropping.
    private func convertToViewRect(_ rect: CGRect, imageSize: CGSize, viewSize: CGSize) -> CGRect {
        guard viewSize.width > 0 else { return .zero }
        
        // Convert top-left and bottom-right corners
        let tl = convertToViewPoint(CGPoint(x: rect.minX, y: rect.minY), imageSize: imageSize, viewSize: viewSize)
        let br = convertToViewPoint(CGPoint(x: rect.maxX, y: rect.maxY), imageSize: imageSize, viewSize: viewSize)
        
        return CGRect(x: tl.x, y: tl.y, width: br.x - tl.x, height: br.y - tl.y)
    }

    // Converts a normalized point (0-1) to screen pixels, accounting for "Aspect Fill" cropping.
    private func convertToViewPoint(_ p: CGPoint, imageSize: CGSize, viewSize: CGSize) -> CGPoint {
        guard viewSize.width > 0, viewSize.height > 0 else { return .zero }
        
        let imgW = imageSize.width
        let imgH = imageSize.height
        let viewW = viewSize.width
        let viewH = viewSize.height
        
        // "Aspect Fill" Logic:
        // Calculate the scale factor that makes the image cover the screen fully.
        // It uses the larger of the width ratio or height ratio.
        let scale = max(viewW / imgW, viewH / imgH)
        
        // The size of the image after scaling up
        let scaledW = imgW * scale
        let scaledH = imgH * scale
        
        // Because we zoomed in, parts of the image hang off the screen.
        // We calculate the offset to center the image.
        let xOffset = (scaledW - viewW) / 2
        let yOffset = (scaledH - viewH) / 2
        
        // 1. De-normalize: (0.5) -> (540 px)
        let px = p.x * imgW
        let py = p.y * imgH
        
        // 2. Scale & Translate: (540 px) * scale - offset -> Screen Coordinate
        let viewX = (px * scale) - xOffset
        let viewY = (py * scale) - yOffset
        
        return CGPoint(x: viewX, y: viewY)
    }
}
