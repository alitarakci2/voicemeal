//
//  BarcodeScannerView.swift
//  VoiceMeal
//

import AVFoundation
import SwiftUI

struct BarcodeScannerView: UIViewControllerRepresentable {
    var onBarcodeDetected: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.onBarcodeDetected = onBarcodeDetected
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}

    final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
        var onBarcodeDetected: ((String) -> Void)?
        private let captureSession = AVCaptureSession()
        private var previewLayer: AVCaptureVideoPreviewLayer?
        private var hasDetected = false
        private let scanLineView = UIView()
        private var scanLineAnimator: UIViewPropertyAnimator?

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black
            setupCamera()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            previewLayer?.frame = view.bounds
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            if !captureSession.isRunning {
                // Delay gives UIKit time to fully present the view before camera starts
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    DispatchQueue.global(qos: .userInitiated).async {
                        self?.captureSession.startRunning()
                    }
                }
            }
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            scanLineAnimator?.stopAnimation(true)
            if captureSession.isRunning {
                captureSession.stopRunning()
            }
        }

        private func setupCamera() {
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device)
            else { return }

            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }

            let output = AVCaptureMetadataOutput()
            if captureSession.canAddOutput(output) {
                captureSession.addOutput(output)
                output.setMetadataObjectsDelegate(self, queue: .main)
                output.metadataObjectTypes = [.ean13, .ean8, .upce, .code128]
            }

            let preview = AVCaptureVideoPreviewLayer(session: captureSession)
            preview.videoGravity = .resizeAspectFill
            preview.frame = view.bounds
            view.layer.addSublayer(preview)
            previewLayer = preview

            addOverlay()

            // Delay gives UIKit time to fully present the view before camera starts
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                DispatchQueue.global(qos: .userInitiated).async {
                    self?.captureSession.startRunning()
                }
            }
        }

        private func addOverlay() {
            let overlayView = UIView(frame: view.bounds)
            overlayView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            overlayView.isUserInteractionEnabled = false
            view.addSubview(overlayView)

            let scanWidth: CGFloat = 300
            let scanHeight: CGFloat = 200
            let scanRect = CGRect(
                x: (view.bounds.width - scanWidth) / 2,
                y: (view.bounds.height - scanHeight) / 2 - 40,
                width: scanWidth,
                height: scanHeight
            )

            // Dimmed background with clear hole
            let dimPath = UIBezierPath(rect: overlayView.bounds)
            let holePath = UIBezierPath(roundedRect: scanRect, cornerRadius: 12)
            dimPath.append(holePath)
            dimPath.usesEvenOddFillRule = true

            let dimLayer = CAShapeLayer()
            dimLayer.path = dimPath.cgPath
            dimLayer.fillRule = .evenOdd
            dimLayer.fillColor = UIColor.black.withAlphaComponent(0.6).cgColor
            overlayView.layer.addSublayer(dimLayer)

            // Border around scan area
            let borderLayer = CAShapeLayer()
            borderLayer.path = UIBezierPath(roundedRect: scanRect, cornerRadius: 12).cgPath
            borderLayer.strokeColor = UIColor(red: 108/255, green: 99/255, blue: 1.0, alpha: 1.0).cgColor
            borderLayer.fillColor = UIColor.clear.cgColor
            borderLayer.lineWidth = 2
            overlayView.layer.addSublayer(borderLayer)

            // Scanning line
            scanLineView.backgroundColor = UIColor(red: 108/255, green: 99/255, blue: 1.0, alpha: 0.7)
            scanLineView.frame = CGRect(x: scanRect.minX + 16, y: scanRect.minY + 8, width: scanWidth - 32, height: 2)
            scanLineView.layer.cornerRadius = 1
            view.addSubview(scanLineView)
            animateScanLine(in: scanRect)

            // Hint label
            let hintLabel = UILabel()
            hintLabel.text = "barcode_hint".localized
            hintLabel.textColor = .white
            hintLabel.font = .systemFont(ofSize: 15, weight: .medium)
            hintLabel.textAlignment = .center
            hintLabel.frame = CGRect(x: 0, y: scanRect.maxY + 20, width: view.bounds.width, height: 24)
            view.addSubview(hintLabel)
        }

        private func animateScanLine(in rect: CGRect) {
            let topY = rect.minY + 8
            let bottomY = rect.maxY - 10
            scanLineView.frame.origin.y = topY

            func animate() {
                let animator = UIViewPropertyAnimator(duration: 2.0, curve: .easeInOut) { [weak self] in
                    self?.scanLineView.frame.origin.y = bottomY
                }
                animator.addCompletion { [weak self] _ in
                    let returnAnimator = UIViewPropertyAnimator(duration: 2.0, curve: .easeInOut) {
                        self?.scanLineView.frame.origin.y = topY
                    }
                    returnAnimator.addCompletion { _ in
                        animate()
                    }
                    self?.scanLineAnimator = returnAnimator
                    returnAnimator.startAnimation()
                }
                self.scanLineAnimator = animator
                animator.startAnimation()
            }
            animate()
        }

        func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard !hasDetected,
                  let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let code = object.stringValue
            else { return }

            hasDetected = true
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()

            captureSession.stopRunning()
            onBarcodeDetected?(code)
        }
    }
}
