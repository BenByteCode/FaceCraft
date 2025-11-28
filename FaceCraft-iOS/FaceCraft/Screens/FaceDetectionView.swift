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
                            // Face Box
                            FaceOverlayShape(boundingBox: face.boundingBox)
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
                            
                            // Mouth
                            GenericLandmarkShape(points: face.mouth)
                                .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                                .foregroundColor(.red)
                        }
                    }
                    .allowsHitTesting(false)
                    // Ensure the overlay coordinate space matches the camera (which ignores safe area)
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
            .onAppear {
                viewModel.start()
            }
            .onDisappear {
                viewModel.stop()
            }
        }
        .ignoresSafeArea() // Important: Ensures (0,0) is top-left of screen, not safe area
    }
}

// MARK: - Shapes

struct FaceOverlayShape: Shape {
    /// Bounding box in View Coordinates (pixels)
    let boundingBox: CGRect
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Since boundingBox is already in view coordinates, we draw it directly.
        // We assume 'rect' is the full screen size (provided by the ZStack/GeometryReader parent)
        path.addRoundedRect(in: boundingBox, cornerSize: CGSize(width: 10, height: 10))
        return path
    }
}

// Renamed from EyeOverlayShape to be generic for Mouth too
struct GenericLandmarkShape: Shape {
    /// Points in View Coordinates (pixels)
    let points: [CGPoint]
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}
