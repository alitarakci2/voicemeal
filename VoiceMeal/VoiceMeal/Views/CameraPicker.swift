//
//  CameraPicker.swift
//  VoiceMeal
//

import AVFoundation
import SwiftUI
import UIKit

struct CameraPicker: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> CameraViewController {
        print("📷 [CameraPicker] makeUIViewController called")
        let vc = CameraViewController()
        vc.onImageCaptured = { image in
            onImageCaptured(image)
            dismiss()
        }
        vc.onCancel = {
            dismiss()
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
}

class CameraViewController: UIViewController {
    var onImageCaptured: ((UIImage) -> Void)?
    var onCancel: (() -> Void)?

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var photoOutput: AVCapturePhotoOutput?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
        setupUI()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func setupCamera() {
        print("📷 [CameraVC] setupCamera called")
        let session = AVCaptureSession()
        session.sessionPreset = .photo

        // Use .builtInWideAngleCamera specifically
        // to avoid the BackWideDual/BackAuto issue
        guard let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) else {
            print("📷 [CameraVC] No camera found")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
            }

            let output = AVCapturePhotoOutput()
            if session.canAddOutput(output) {
                session.addOutput(output)
                self.photoOutput = output
            }

            self.captureSession = session

            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = view.bounds
            view.layer.insertSublayer(previewLayer, at: 0)
            self.previewLayer = previewLayer

            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
                print("📷 [CameraVC] Session started")
            }
        } catch {
            print("📷 [CameraVC] Setup error: \(error)")
        }
    }

    private func setupUI() {
        // Capture button
        let captureButton = UIButton(type: .system)
        captureButton.backgroundColor = .white
        captureButton.layer.cornerRadius = 35
        captureButton.frame = CGRect(
            x: view.bounds.midX - 35,
            y: view.bounds.height - 120,
            width: 70,
            height: 70
        )
        captureButton.addTarget(
            self,
            action: #selector(takePhoto),
            for: .touchUpInside
        )
        view.addSubview(captureButton)

        // Inner circle
        let innerCircle = UIView()
        innerCircle.backgroundColor = .white
        innerCircle.layer.cornerRadius = 28
        innerCircle.layer.borderWidth = 3
        innerCircle.layer.borderColor = UIColor.black.cgColor
        innerCircle.frame = CGRect(x: 6, y: 6, width: 58, height: 58)
        innerCircle.isUserInteractionEnabled = false
        captureButton.addSubview(innerCircle)

        // Cancel button
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("İptal", for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 17)
        cancelButton.frame = CGRect(
            x: 20,
            y: 60,
            width: 80,
            height: 44
        )
        cancelButton.addTarget(
            self,
            action: #selector(cancel),
            for: .touchUpInside
        )
        view.addSubview(cancelButton)
    }

    @objc private func takePhoto() {
        print("📷 [CameraVC] takePhoto tapped")
        guard let output = photoOutput else { return }
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)
    }

    @objc private func cancel() {
        print("📷 [CameraVC] cancel tapped")
        onCancel?()
    }
}

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        print("📷 [CameraVC] Photo captured")
        if let error = error {
            print("📷 [CameraVC] Error: \(error)")
            return
        }
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            print("📷 [CameraVC] Could not get image")
            return
        }
        print("📷 [CameraVC] Calling onImageCaptured")
        DispatchQueue.main.async {
            self.onImageCaptured?(image)
        }
    }
}
