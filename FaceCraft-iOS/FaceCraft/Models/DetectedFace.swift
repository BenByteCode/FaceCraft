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
    let boundingBox: CGRect
    let leftEye: [CGPoint]
    let rightEye: [CGPoint]
    let mouth: [CGPoint]
    let nose: [CGPoint]
    let noseCrest: [CGPoint]
    let faceContour: [CGPoint]
}
