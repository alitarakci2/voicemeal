//
//  HomeView+CameraFlow.swift
//  VoiceMeal
//

import AVFoundation
import SwiftUI

extension HomeView {

    var photoLoadingOverlay: some View {
        ZStack {
            Color(hex: "0A0A0F")
                .ignoresSafeArea()

            VStack(spacing: 20) {
                if let image = capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
                }

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.3)

                VStack(spacing: 6) {
                    Text(L.analyzingMeal.localized)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    Text(L.mayTakeSeconds.localized)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .transition(.opacity)
        .zIndex(100)
    }

    func handleCameraTap() {
        print("📷 [Camera] Button tapped, setting showCamera=true")
        #if targetEnvironment(simulator)
        errorMessage = "camera_simulator_error".localized
        #else
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showCamera = true
                    } else {
                        showCameraPermissionDenied = true
                    }
                }
            }
        case .denied, .restricted:
            showCameraPermissionDenied = true
        @unknown default:
            showCameraPermissionDenied = true
        }
        #endif
    }
}
