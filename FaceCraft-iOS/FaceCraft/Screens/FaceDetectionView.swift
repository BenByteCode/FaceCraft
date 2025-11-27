//
//  ContentView.swift
//  FaceCraft
//
//  Created by Okjoon Kim on 11/27/25.
//

import SwiftUI

struct FaceDetectionView: View {
    @StateObject private var cameraService = CameraFaceDetectionService()
    
    @State private var showOverlays = true
    @State private var showDebugHUD = true
    
    var body: some View {
        ZStack {
            // Camera preview
            CameraPreview(session: cameraService.session)
                .ignoresSafeArea()
            
            // Face overlays
            if showOverlays {
                GeometryReader { geo in
                    ForEach(cameraService.faces) { face in
                        FaceOverlayShape(normalizedRect: face.boundingBox)
                            .stroke(style: StrokeStyle(lineWidth: 2,
                                                       lineCap: .round,
                                                       lineJoin: .round))
                            .foregroundColor(.yellow)
                        
                        EyeOverlayShape(
                            normalizedEyePoints: face.leftEye,
                            faceBoundingBox: face.boundingBox
                        )
                        .stroke(style: StrokeStyle(lineWidth: 2))
                        
                        EyeOverlayShape(
                            normalizedEyePoints: face.rightEye,
                            faceBoundingBox: face.boundingBox
                        )
                        .stroke(style: StrokeStyle(lineWidth: 2))
                    }
                    .foregroundColor(.blue)
                }
                .allowsHitTesting(false)
            }
            
            // Debug HUD
            if showDebugHUD {
                VStack {
                    HStack {
                        Text("FaceCraft")
                            .font(.headline)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                        
                        Spacer()
                        
                        Text("Faces: \(cameraService.faces.count)")
                            .font(.subheadline.monospacedDigit())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                    }
                    .padding()
                    
                    Spacer()
                }
                .foregroundColor(.white)
            }
            
            // Bottom controls
            VStack {
                Spacer()
                
                HStack(spacing: 16) {
                    Button {
                        showOverlays.toggle()
                    } label: {
                        Label(showOverlays ? "Hide Overlay" : "Show Overlay",
                              systemImage: showOverlays ? "eye.slash" : "eye")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                    }
                    
                    Button {
                        showDebugHUD.toggle()
                    } label: {
                        Label("HUD", systemImage: showDebugHUD ? "dot.radiowaves.left.and.right" : "wave.3.right")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                    }
                }
                .padding(.bottom, 24)
            }
            .foregroundColor(.white)
        }
    }
}

struct FaceOverlayShape: Shape {
    /// Normalized rect from Vision (0–1, origin bottom-left)
    let normalizedRect: CGRect
    
    func path(in rect: CGRect) -> Path {
        // Convert from Vision to view coordinates
        let w = normalizedRect.width * rect.width
        let h = normalizedRect.height * rect.height
        let x = normalizedRect.origin.x * rect.width
        // Flip Y
        let y = (1 - normalizedRect.origin.y - normalizedRect.height) * rect.height
        
        var path = Path()
        let faceRect = CGRect(x: x, y: y, width: w, height: h)
        path.addRoundedRect(in: faceRect, cornerSize: CGSize(width: 10, height: 10))
        return path
    }
}

struct EyeOverlayShape: Shape {
    /// Eye points normalized in face coordinates (0–1, origin bottom-left within face box)
    let normalizedEyePoints: [CGPoint]
    /// Face bounding box normalized in full image coordinates
    let faceBoundingBox: CGRect
    
    func path(in rect: CGRect) -> Path {
        guard !normalizedEyePoints.isEmpty else { return Path() }
        
        // First convert each eye point to full-image normalized coords,
        // then to view coords.
        let pointsInView: [CGPoint] = normalizedEyePoints.map { p in
            // Eye point relative to full image:
            let normX = faceBoundingBox.origin.x + p.x * faceBoundingBox.width
            let normY = faceBoundingBox.origin.y + p.y * faceBoundingBox.height
            
            let x = normX * rect.width
            // Flip Y
            let y = (1 - normY) * rect.height
            return CGPoint(x: x, y: y)
        }
        
        var path = Path()
        if let first = pointsInView.first {
            path.move(to: first)
            for pt in pointsInView.dropFirst() {
                path.addLine(to: pt)
            }
            path.closeSubpath()
        }
        return path
    }
}

//#Preview {
//    FaceDetectionView()
//}
