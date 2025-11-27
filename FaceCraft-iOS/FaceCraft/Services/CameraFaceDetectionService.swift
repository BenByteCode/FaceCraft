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

final class CameraFaceDetectionService: NSObject {
    
    let session = AVCaptureSession()
    
    /// Callback to deliver detected faces
    var onFacesDetected: (([DetectedFace]) -> Void)?
    
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let videoOutput = AVCaptureVideoDataOutput()
    private var lastRequestTime: CFTimeInterval = 0
    private let minRequestInterval: CFTimeInterval = 0.1
    
    override init() {
        super.init()
        configureSession()
    }
    
    private func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            
            self.session.beginConfiguration()
            self.session.sessionPreset = .high
            
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                        for: .video,
                        position: .front)
               ?? AVCaptureDevice.default(.builtInWideAngleCamera,
                        for: .video,
                        position: .back),
                  let input = try? AVCaptureDeviceInput(device: device)
            else { return }
            
            if self.session.canAddInput(input) { self.session.addInput(input) }
            
            self.videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera.video.queue"))
            self.videoOutput.alwaysDiscardsLateVideoFrames = true
            
            if self.session.canAddOutput(self.videoOutput) {
                self.session.addOutput(self.videoOutput)
            }
            
            if let connection = self.videoOutput.connection(with: .video),
               connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            
            self.session.commitConfiguration()
            self.session.startRunning()
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
        
        let request = VNDetectFaceLandmarksRequest { [weak self] request, error in
            guard let self else { return }
            guard error == nil else { return }
            self.processVisionResults(request.results)
        }
        
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .leftMirrored
        )
        
        try? handler.perform([request])
    }
    
    private func processVisionResults(_ results: [Any]?) {
        guard let faceObservations = results as? [VNFaceObservation] else { return }
        
        let faces: [DetectedFace] = faceObservations.compactMap { obs in
            guard let landmarks = obs.landmarks else {
                return DetectedFace(boundingBox: obs.boundingBox, leftEye: [], rightEye: [])
            }
            
            func convert(_ region: VNFaceLandmarkRegion2D?) -> [CGPoint] {
                guard let region else { return [] }
                return region.normalizedPoints.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
            }
            
            return DetectedFace(
                boundingBox: obs.boundingBox,
                leftEye: convert(landmarks.leftEye),
                rightEye: convert(landmarks.rightEye)
            )
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.onFacesDetected?(faces)
        }
    }
}
