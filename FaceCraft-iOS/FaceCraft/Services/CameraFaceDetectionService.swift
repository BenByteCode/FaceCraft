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

final class CameraFaceDetectionService: NSObject {
    
    // MARK: - Public
    
    // Support for ViewModel callback pattern
    var onFacesDetected: (([DetectedFace]) -> Void)?
    
    let session = AVCaptureSession()
    
    /// Must be set by the UI (via ViewModel) to calculate coordinates correctly
    var previewViewSize: CGSize = .zero
    
    // MARK: - Private
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let videoOutput = AVCaptureVideoDataOutput()
    private let visionQueue = DispatchQueue(label: "camera.vision.queue")
    
    private var lastRequestTime: CFTimeInterval = 0
    private let minRequestInterval: CFTimeInterval = 0.06 // ~15 FPS
    
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

// MARK: - Session Setup
extension CameraFaceDetectionService {
    
    private func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.session.beginConfiguration()
            self.session.sessionPreset = .high
            
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                       for: .video,
                                                       position: .front),
                  let input = try? AVCaptureDeviceInput(device: device)
            else { return }
            
            if self.session.canAddInput(input) {
                self.session.addInput(input)
            }
            
            self.videoOutput.setSampleBufferDelegate(self, queue: self.visionQueue)
            self.videoOutput.alwaysDiscardsLateVideoFrames = true
            
            if self.session.canAddOutput(self.videoOutput) {
                self.session.addOutput(self.videoOutput)
            }
            
            // Set orientation to Portrait (Physical Upright)
            if let conn = self.videoOutput.connection(with: .video),
               conn.isVideoOrientationSupported {
                conn.videoOrientation = .portrait
                conn.isVideoMirrored = true
            }
            
            self.session.commitConfiguration()
        }
    }
}

// MARK: - Vision Processing
extension CameraFaceDetectionService: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        
        let now = CACurrentMediaTime()
        guard now - lastRequestTime > minRequestInterval else { return }
        lastRequestTime = now
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let req = VNDetectFaceLandmarksRequest { [weak self] request, error in
            guard let self = self, error == nil else { return }
            self.handleVisionResults(request.results, pixelBuffer: pixelBuffer)
        }
        
        // Orientation is .up because the buffer is ALREADY mirrored and rotated
        // by the AVCaptureConnection to match the screen exactly.
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .up,
            options: [:]
        )
        
        try? handler.perform([req])
    }
    
    private func handleVisionResults(_ results: [Any]?, pixelBuffer: CVPixelBuffer) {
        guard let observations = results as? [VNFaceObservation] else { return }
        
        let viewSize = self.previewViewSize
        let imgWidth = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let imgHeight = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        let imgSize = CGSize(width: imgWidth, height: imgHeight)
        
        let faces: [DetectedFace] = observations.compactMap { face in
            
            // 1. Calculate Bounding Box (Vision Bottom-Left -> UIKit Top-Left)
            let visionBox = face.boundingBox
            let normalizedBox = CGRect(
                x: visionBox.origin.x,
                y: 1 - visionBox.origin.y - visionBox.height,
                width: visionBox.width,
                height: visionBox.height
            )
            
            let bbox = self.convertToViewRect(normalizedBox, imageSize: imgSize, viewSize: viewSize)
            
            guard let landmarks = face.landmarks else {
                return DetectedFace(boundingBox: bbox, leftEye: [], rightEye: [], mouth: [], nose: [], noseCrest: [], faceContour: [])
            }
            
            // 2. Convert landmarks
            func convertRegion(_ region: VNFaceLandmarkRegion2D?) -> [CGPoint] {
                guard let region = region else { return [] }
                
                return region.normalizedPoints.map { point in
                    let lx = point.x
                    let ly = point.y
                    
                    // Local landmark -> Global Vision (Bottom-Left)
                    let visionX = visionBox.origin.x + lx * visionBox.width
                    let visionY = visionBox.origin.y + ly * visionBox.height
                    
                    // Vision -> UIKit (Top-Left)
                    let normalizedPoint = CGPoint(x: visionX, y: 1 - visionY)
                    
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
        
        DispatchQueue.main.async { [weak self] in
            // Trigger Callback (if used via ViewModel)
            self?.onFacesDetected?(faces)
        }
    }
}

// MARK: - Aspect Fill Math
extension CameraFaceDetectionService {
    
    private func convertToViewRect(_ rect: CGRect, imageSize: CGSize, viewSize: CGSize) -> CGRect {
        guard viewSize.width > 0 else { return .zero }
        let tl = convertToViewPoint(CGPoint(x: rect.minX, y: rect.minY), imageSize: imageSize, viewSize: viewSize)
        let br = convertToViewPoint(CGPoint(x: rect.maxX, y: rect.maxY), imageSize: imageSize, viewSize: viewSize)
        return CGRect(x: tl.x, y: tl.y, width: br.x - tl.x, height: br.y - tl.y)
    }

    private func convertToViewPoint(_ p: CGPoint, imageSize: CGSize, viewSize: CGSize) -> CGPoint {
        guard viewSize.width > 0, viewSize.height > 0 else { return .zero }
        
        let imgW = imageSize.width
        let imgH = imageSize.height
        let viewW = viewSize.width
        let viewH = viewSize.height
        
        let scale = max(viewW / imgW, viewH / imgH)
        let scaledW = imgW * scale
        let scaledH = imgH * scale
        
        let xOffset = (scaledW - viewW) / 2
        let yOffset = (scaledH - viewH) / 2
        
        let px = p.x * imgW
        let py = p.y * imgH
        
        let viewX = (px * scale) - xOffset
        let viewY = (py * scale) - yOffset
        
        return CGPoint(x: viewX, y: viewY)
    }
}
