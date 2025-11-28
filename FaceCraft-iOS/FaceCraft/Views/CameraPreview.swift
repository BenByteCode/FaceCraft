//
//  CameraPreview.swift
//  FaceCraft
//
//  Created by Okjoon Kim on 11/27/25.
//

import Foundation
import SwiftUI
import AVFoundation

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var viewModel: CameraViewModel
    
    final class VideoPreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            return layer as! AVCaptureVideoPreviewLayer
        }
    }
    
    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.videoPreviewLayer.session = viewModel.service.session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        // IMPORTANT: update preview size for aspect-fill transform alignment
        DispatchQueue.main.async {
            let size = uiView.bounds.size
            if size != .zero {
                viewModel.service.previewViewSize = size
            }
        }
    }
}
