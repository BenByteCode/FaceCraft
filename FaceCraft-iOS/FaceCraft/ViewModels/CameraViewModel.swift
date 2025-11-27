//
//  CameraViewModel.swift
//  FaceCraft
//
//  Created by Okjoon Kim on 11/27/25.
//

import Foundation
import SwiftUI
import Combine

final class CameraViewModel: ObservableObject {
    
    @Published var faces: [DetectedFace] = []
    
    let service: CameraFaceDetectionService
    
    init(service: CameraFaceDetectionService = CameraFaceDetectionService()) {
        self.service = service
        
        // Receive updates from the service
        service.onFacesDetected = { [weak self] detectedFaces in
            self?.faces = detectedFaces
        }
    }
}
