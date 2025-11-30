//
//  ContentView.swift
//  FaceCraft
//
//  Created by Okjoon Kim on 11/27/25.
//

import SwiftUI
import AVFoundation

struct FaceDetectionView: View {
    @StateObject private var viewModel = CameraViewModel()
    
    @State private var showOverlays = true
    @State private var showDebugHUD = true
    @State private var showMUstaches = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Camera preview
                CameraPreview(viewModel: viewModel)
                    .ignoresSafeArea()
                
                // Face overlays
                if showOverlays {
                    // We use a ZStack here so the shapes draw in the full screen coordinate space
                    ZStack {
                        ForEach(viewModel.faces) { face in
                            // Face Bounding Box
                            FaceBoundingBoxShape(boundingBox: face.boundingBox)
                                .stroke(style: StrokeStyle(lineWidth: 2,
                                                           lineCap: .round,
                                                           lineJoin: .round))
                                .foregroundColor(.cyan)
                            
                            // Face Contour
                            GenericLandmarkShape(points: face.faceContour)
                                .stroke(style: StrokeStyle(lineWidth: 2,
                                                           lineCap: .round,
                                                           lineJoin: .round))
                                .foregroundColor(.yellow)
                            
                            // Left Eye
                            GenericLandmarkShape(points: face.leftEye)
                                .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                                .foregroundColor(.green)
                            
                            // Right Eye
                            GenericLandmarkShape(points: face.rightEye)
                                .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                                .foregroundColor(.green)
                            
                            // Nose Base
                            GenericLandmarkShape(points: face.nose)
                                .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                                .foregroundColor(.orange)
                            
                            // Nose Bridge (Crest)
                            GenericLandmarkShape(points: face.noseCrest)
                                .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                                .foregroundColor(.orange)
                            
                            // Mouth
                            GenericLandmarkShape(points: face.mouth)
                                .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                                .foregroundColor(.red)
                            
                            // Mustache
                            if showMUstaches {
                                MustacheView(face: face)
                            }
                        }
                    }
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
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
                            
                            Text("Faces: \(viewModel.faces.count)")
                                .font(.subheadline.monospacedDigit())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial)
                                .cornerRadius(8)
                        }
                        .padding()
                        .padding(.top, 50)
                        
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
                            Label("Overlay",
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
                        
                        Button {
                            showMUstaches.toggle()
                        } label: {
                            Label("Mustache",
                                  systemImage: showMUstaches ? "mustache" : "mustache.fill") // SF Symbol fun
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
            .onAppear {
                viewModel.start()
            }
            .onDisappear {
                viewModel.stop()
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Mustache Component

struct MustacheView: View {
    let face: DetectedFace
    
    var body: some View {
        let geometry = calculateMustacheGeometry(face: face)
        
        // Draw the mustache
        MustacheShape()
            .fill(Color.black)
            .frame(width: geometry.width, height: geometry.height)
            .position(geometry.center)
            .rotationEffect(geometry.angle)
            // Add a slight shadow for depth
            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
    }
    
    struct MustacheGeometry {
        let center: CGPoint
        let width: CGFloat
        let height: CGFloat
        let angle: Angle
    }
    
    private func calculateMustacheGeometry(face: DetectedFace) -> MustacheGeometry {
        // 1. Calculate Center: Average of Nose Bottom and Mouth Top
        // Simple approximation: Average of all nose points vs all mouth points
        let noseCenter = averagePoint(face.nose)
        let mouthCenter = averagePoint(face.mouth)
        
        // The mustache sits between nose and mouth (Philtrum)
        // We bias slightly closer to the nose (0.4 distance from nose)
        let centerX = (noseCenter.x + mouthCenter.x) / 2
        let centerY = noseCenter.y + (mouthCenter.y - noseCenter.y) * 0.4
        
        // 2. Calculate Width: Based on mouth width
        // Handlebar mustaches are wider than the mouth!
        let mouthWidth = boundingWidth(points: face.mouth)
        let width = mouthWidth * 1.8
        let height = width * 0.3 // Aspect ratio for the shape
        
        // 3. Calculate Rotation: Based on the angle between eyes
        let leftEyeCenter = averagePoint(face.leftEye)
        let rightEyeCenter = averagePoint(face.rightEye)
        
        let deltaY = rightEyeCenter.y - leftEyeCenter.y
        let deltaX = rightEyeCenter.x - leftEyeCenter.x
        let angleInRadians = atan2(deltaY, deltaX)
        
        return MustacheGeometry(
            center: CGPoint(x: centerX, y: centerY),
            width: width,
            height: height,
            angle: Angle(radians: Double(angleInRadians))
        )
    }
    
    private func averagePoint(_ points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        let sum = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        return CGPoint(x: sum.x / CGFloat(points.count), y: sum.y / CGFloat(points.count))
    }
    
    private func boundingWidth(points: [CGPoint]) -> CGFloat {
        guard !points.isEmpty else { return 0 }
        let minX = points.map { $0.x }.min() ?? 0
        let maxX = points.map { $0.x }.max() ?? 0
        return maxX - minX
    }
}

// A custom shape that draws a classic "Handlebar" mustache
struct MustacheShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let w = rect.width
        let h = rect.height
        
        // Start center top
        path.move(to: CGPoint(x: w * 0.5, y: h * 0.2))
        
        // Right side curve (top)
        path.addCurve(to: CGPoint(x: w, y: h * 0.4),
                      control1: CGPoint(x: w * 0.6, y: h * 0.1),
                      control2: CGPoint(x: w * 0.9, y: h * 0.1))
        
        // Right side curl (tip)
        path.addCurve(to: CGPoint(x: w * 0.85, y: h * 0.6),
                      control1: CGPoint(x: w * 1.05, y: h * 0.6),
                      control2: CGPoint(x: w * 0.95, y: h * 0.7))
        
        // Right side curve (bottom) to center
        path.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.5),
                      control1: CGPoint(x: w * 0.8, y: h * 0.5),
                      control2: CGPoint(x: w * 0.6, y: h * 0.45))
        
        // Left side curve (bottom) from center
        path.addCurve(to: CGPoint(x: w * 0.15, y: h * 0.6),
                      control1: CGPoint(x: w * 0.4, y: h * 0.45),
                      control2: CGPoint(x: w * 0.2, y: h * 0.5))
        
        // Left side curl (tip)
        path.addCurve(to: CGPoint(x: 0, y: h * 0.4),
                      control1: CGPoint(x: w * 0.05, y: h * 0.7),
                      control2: CGPoint(x: -0.05 * w, y: h * 0.6))

        // Left side curve (top) back to start
        path.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.2),
                      control1: CGPoint(x: w * 0.1, y: h * 0.1),
                      control2: CGPoint(x: w * 0.4, y: h * 0.1))
        
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Shapes (Standard)

struct FaceBoundingBoxShape: Shape {
    let boundingBox: CGRect
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(in: boundingBox, cornerSize: CGSize(width: 10, height: 10))
        return path
    }
}

struct GenericLandmarkShape: Shape {
    let points: [CGPoint]
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }
}
