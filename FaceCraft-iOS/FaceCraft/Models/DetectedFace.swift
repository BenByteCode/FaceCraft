//
//  DetectedFace.swift
//  FaceCraft
//
//  Created by Okjoon Kim on 11/27/25.
//

import Foundation
import CoreGraphics

struct DetectedFace: Identifiable {
    let id = UUID()
    let boundingBox: CGRect            // In view coordinates
    let leftEye: [CGPoint]             // In view coordinates
    let rightEye: [CGPoint]            // In view coordinates
}
