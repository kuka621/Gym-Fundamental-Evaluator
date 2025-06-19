//
//  CameraView.swift
//  Gym
//
//  Created by Gianluca Latronico on 25/03/25.
//

import SwiftUI
import AVFoundation
import ReplayKit
import CoreML
import Photos

struct CameraView: UIViewControllerRepresentable {
    var esercizio: String
    var dismissAction: (() -> Void)
    
    class CameraViewController: UIViewController, RPPreviewViewControllerDelegate {
        var captureSession: AVCaptureSession!
        var previewLayer: AVCaptureVideoPreviewLayer!
        var esercizioLabel: UILabel!
        var esercizioNome: String = ""
        var exitButton: UIButton!
        var recordButton: UIButton!
        var modelButton: UIButton!
        var dismissAction: (() -> Void)?
        let screenRecorder = RPScreenRecorder.shared()
        var isRecording = false
        var countdownWindow: UIWindow?
        
        //MODELLI
        var poseModel: MLModel?
        
        override func viewDidLoad(){
            super.viewDidLoad()
            setupCamera()
            setupGrapich()
            requestCameraPermission()
            
        }
        
        func requestCameraPermission(){
            AVCaptureDevice.requestAccess(for: .video) { garanted in
                if garanted{
                    print("Accesso alla fotocamera consentito")
                } else {
                    print("Accesso alla fotocamera negato")
                }
            }
        }

        func requestPhotoLibraryAccessIfNeeded() {
            PHPhotoLibrary.requestAuthorization { status in
                switch status {
                case .authorized, .limited:
                    print("✅ Accesso alla libreria consentito")
                case .denied, .restricted:
                    print("❌ Accesso alla libreria negato")
                case .notDetermined:
                    print("ℹ️ Accesso non determinato")
                @unknown default:
                    break
                }
            }
        }

        
        func setupCamera() {
            captureSession = AVCaptureSession()
            
            guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
                print("Accesso alla camera non riuscito!")
                return
            }
            
            do{
                let input = try AVCaptureDeviceInput(device: frontCamera)
                captureSession.addInput(input)
            } catch {
                print("Errore in fase di accesso!")
                return
            }
            
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = view.bounds
            view.layer.addSublayer(previewLayer)
            
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
            }
        }
        
        func setupGrapich() {
            //Bottone ESCI
            exitButton = UIButton(type: .system)
            exitButton = UIButton(frame: CGRect(x: 20, y: 50, width: 60, height: 30))
            exitButton.setTitle("Esci", for: .normal)
            exitButton.backgroundColor = .red
            exitButton.layer.cornerRadius = 8
            exitButton.addTarget(self, action: #selector(exitCamera), for: .touchUpInside)
            view.addSubview(exitButton)
            
            //Nome esercizio
            esercizioLabel = UILabel(frame: CGRect(x: view.bounds.midX - 75, y: 50, width: 150, height: 30))
            esercizioLabel.text = "\(esercizioNome)"
            esercizioLabel.textAlignment = .center
            esercizioLabel.textColor = .white
            esercizioLabel.font = UIFont.boldSystemFont(ofSize: 24)
            esercizioLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
            esercizioLabel.layer.cornerRadius = 8
            esercizioLabel.clipsToBounds = true
            view.addSubview(esercizioLabel)
            
            //Bottone registra
            recordButton = UIButton(frame: CGRect(x: view.bounds.midX - 35, y: view.bounds.height - 100, width: 70, height: 70))
            recordButton.setImage(UIImage(named: "recButton"), for: .normal)
            recordButton.layer.cornerRadius = 35
            recordButton.layer.masksToBounds = true
            recordButton.addTarget(self, action: #selector(startRec), for: .touchUpInside)
            view.addSubview(recordButton)
        }
        
        @objc func exitCamera() {
            poseModel = nil
            
            dismissAction?()
        }
        
        func loadModels() -> MLModel? {
            do {
                if poseModel == nil {
                    let config = MLModelConfiguration()
                    config.computeUnits = .cpuOnly
                    poseModel = try _3D_CNN_model_v16(configuration: config).model
                    print("✅ Modello di classificazione pose caricato")
                } else {
                    print("✅ Modello già caricato")
                }
                return poseModel
            } catch {
                print("❌ Errore nel caricamento del modello: \(error)")
                return nil
            }
        }
        
        @objc func startRec(){
            if isRecording {
                // 🛑 STOP REGISTRAZIONE
                if screenRecorder.isRecording {
                    screenRecorder.stopRecording { previewVC, error in
                        DispatchQueue.main.async {
                            self.recordButton.setImage(UIImage(named: "recButton"), for: .normal)
                        }
                        
                        if let error = error {
                            print("Errore nello stop della registrazione: \(error.localizedDescription)")
                            return
                        }
                        
                        // Mostra anteprima per salvare il video
                        if let previewVC = previewVC {
                            previewVC.previewControllerDelegate = self
                            self.present(previewVC, animated: true)
                        }
                        self.isRecording = false
                    }
                } else {
                    print("Nessuna registrazione attiva da fare")
                }
            } else {
                // 🎥 START REGISTRAZIONE
                self.showCountdown(seconds: 10) {
                    self.screenRecorder.startRecording { error in
                        if let error = error {
                            print("Errore nell'avvio della registrazione: \(error.localizedDescription)")
                            return
                        }

                        DispatchQueue.main.async {
                            self.recordButton.setImage(UIImage(named: "recButtonPressed"), for: .normal)
                        }

                        print("Registrazione iniziata!")
                        self.isRecording = true
                    }
                }
            }
        }
        
        func showCountdown(seconds: Int, completion: @escaping () -> Void) {
            let countdownLabel = UILabel()
            countdownLabel.textAlignment = .center
            countdownLabel.font = UIFont.systemFont(ofSize: 100, weight: .bold)
            countdownLabel.textColor = .white
            countdownLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
            countdownLabel.layer.cornerRadius = 20
            countdownLabel.clipsToBounds = true
            countdownLabel.translatesAutoresizingMaskIntoConstraints = false

            self.view.addSubview(countdownLabel)

            NSLayoutConstraint.activate([
                countdownLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                countdownLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                countdownLabel.widthAnchor.constraint(equalToConstant: 200),
                countdownLabel.heightAnchor.constraint(equalToConstant: 200)
            ])

            var current = seconds

            func animateNext() {
                guard current > 0 else {
                    countdownLabel.removeFromSuperview()
                    completion() // 👉 Avvia la registrazione dopo il countdown
                    return
                }

                countdownLabel.text = "\(current)"
                countdownLabel.alpha = 1.0
                countdownLabel.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)

                UIView.animate(withDuration: 0.9, delay: 0, options: .curveEaseOut, animations: {
                    countdownLabel.transform = CGAffineTransform.identity
                    countdownLabel.alpha = 1.0
                }) { _ in
                    UIView.animate(withDuration: 0.1, animations: {
                        countdownLabel.alpha = 0.0
                    }) { _ in
                        current -= 1
                        animateNext()
                    }
                }
            }

            animateNext()
        }
        
        func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
            previewController.dismiss(animated: true)
        }
        
        func previewController(_ previewController: RPPreviewViewController, didFinishWithActivityTypes activityTypes: Set<String>) {
            if activityTypes.contains(UIActivity.ActivityType.saveToCameraRoll.rawValue) {
                print("✅ Video salvato")

                getLastSavedVideo { url in
                    guard let videoURL = url else {
                        print("❌ Errore nel recupero del video")
                        return
                    }

                    print("📁 Video URL: \(videoURL)")

                    Task { [weak self] in
                        guard let self = self else { return }

                        do {
                            guard let model = self.loadModels() else {
                                print("❌ Modello non caricato")
                                return
                            }

                            let (label, probabilities) = try await analyzeVideoWith3DCNN(videoURL: videoURL, model: model)

                            print("✅ Esercizio rilevato: \(label)")
                            print("🔢 Probabilità: \(probabilities)")

                            let esercizioAtteso =  self.esercizioNome.lowercased()
                            if label.lowercased() != esercizioAtteso {
                                await MainActor.run {
                                    let alert = UIAlertController(
                                        title: "Esercizio errato",
                                        message: "Hai eseguito un esercizio diverso da quello selezionato.",
                                        preferredStyle: .alert
                                    )
                                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                                    self.present(alert, animated: true)
                                }
                                return
                            }

                            // ✅ Esercizio corretto → avvia post-processing
                            DispatchQueue.global().async {
                                autoreleasepool {
                                    PostProcessingManager().analyze(videoURL: videoURL, forExercise: esercizioAtteso) { result in
                                        print("🧠 Analisi completata!")
                                        print("🔁 Ripetizioni: \(result.repetitionCount)")
                                        print("🔁 Ripetizioni incorrette: \(result.incompleteCount)")
                                        print("⚠️ Errori: \(result.errors)")
                                        print("📐 Angoli: \(result.angles)")

                                        DispatchQueue.main.async {
                                            let recapView = RecapView(result: result)
                                            let hosting = UIHostingController(rootView: recapView)
                                            self.present(hosting, animated: true)
                                        }
                                    }
                                }
                            }

                        } catch {
                            print("❌ Errore nell’analisi video: \(error)")
                        }
                    }
                }
            } else {
                print("❌ Salvataggio annullato - nessuna analisi")
            }

            previewController.dismiss(animated: true)
        }


        func getLastSavedVideo(completion: @escaping (URL?) -> Void) {
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            options.fetchLimit = 1

            let result = PHAsset.fetchAssets(with: .video, options: options)
            
            guard let asset = result.firstObject else {
                print("❌ Nessun video trovato nella libreria")
                completion(nil)
                return
            }

            let optionsVideo = PHVideoRequestOptions()
            optionsVideo.deliveryMode = .highQualityFormat
            optionsVideo.isNetworkAccessAllowed = true

            PHImageManager.default().requestAVAsset(forVideo: asset, options: optionsVideo) { (avAsset, _, _) in
                if let urlAsset = avAsset as? AVURLAsset {
                    print("📁 Recuperato video da libreria: \(urlAsset.url)")
                    completion(urlAsset.url)
                } else {
                    print("❌ Errore nel recupero AVAsset")
                    completion(nil)
                }
            }
        }

    }
    
    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.esercizioNome = esercizio
        controller.dismissAction = dismissAction
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
}



