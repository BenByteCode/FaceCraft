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
import Combine

final class CameraFaceDetectionService: NSObject, ObservableObject {
    // Exposed to SwiftUI
    @Published var faces: [DetectedFace] = []
    
    let session = AVCaptureSession()
    
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let videoOutput = AVCaptureVideoDataOutput()
    private var lastRequestTime: CFTimeInterval = 0
    private let minRequestInterval: CFTimeInterval = 0.1 // 10 fps max for Vision
    
    override init() {
        super.init()
        configureSession()
    }
    
    private func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            
            self.session.beginConfiguration()
            self.session.sessionPreset = .high
            
            // Camera input
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                       for: .video,
                                                       position: .front) ?? // front camera
                               AVCaptureDevice.default(.builtInWideAngleCamera,
                                                       for: .video,
                                                       position: .back),
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input) else {
                print("Failed to create camera input.")
                self.session.commitConfiguration()
                return
            }
            self.session.addInput(input)
            
            // Video output
            self.videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera.video.queue"))
            self.videoOutput.alwaysDiscardsLateVideoFrames = true
            
            if self.session.canAddOutput(self.videoOutput) {
                self.session.addOutput(self.videoOutput)
            }
            
            // Match orientation
            if let connection = self.videoOutput.connection(with: .video),
               connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            
            self.session.commitConfiguration()
            self.session.startRunning()
        }
    }
}

extension CameraFaceDetectionService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        
        let now = CACurrentMediaTime()
        guard now - lastRequestTime > minRequestInterval else {
            return // throttle Vision
        }
        lastRequestTime = now
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let request = VNDetectFaceLandmarksRequest { [weak self] request, error in
            guard let self else { return }
            if let error = error {
                print("Vision error: \(error)")
                return
            }
            self.handleVisionResults(request.results, in: pixelBuffer)
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: .leftMirrored, // front-camera portrait
                                            options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("Failed to perform Vision request: \(error)")
        }
    }
    
    private func handleVisionResults(_ results: [Any]?, in pixelBuffer: CVPixelBuffer) {
        guard let faceObservations = results as? [VNFaceObservation], !faceObservations.isEmpty else {
            DispatchQueue.main.async {
                self.faces = []
            }
            return
        }
        
        // We only know normalized coordinates here; actual view size will be known in SwiftUI.
        // So: we’ll store them for a "virtual" size (e.g., 1x1), and scale later.
        // BUT: it’s usually easier to directly convert in SwiftUI.
        //
        // For simplicity, we’ll keep normalized bounding boxes & points,
        // and convert them in the SwiftUI overlay.
        
        let normalizedFaces: [DetectedFace] = faceObservations.compactMap { obs in
            let bbox = obs.boundingBox // normalized (0–1)
            
            guard let landmarks = obs.landmarks else {
                return DetectedFace(
                    boundingBox: bbox,
                    leftEye: [],
                    rightEye: []
                )
            }
            
            func convertPoints(_ region: VNFaceLandmarkRegion2D?) -> [CGPoint] {
                guard let region = region else { return [] }
                return region.normalizedPoints.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
            }
            
            let leftEyePoints = convertPoints(landmarks.leftEye)
            let rightEyePoints = convertPoints(landmarks.rightEye)
            
            return DetectedFace(
                boundingBox: bbox,
                leftEye: leftEyePoints,
                rightEye: rightEyePoints
            )
        }
        
        DispatchQueue.main.async {
            self.faces = normalizedFaces
        }
    }
}
