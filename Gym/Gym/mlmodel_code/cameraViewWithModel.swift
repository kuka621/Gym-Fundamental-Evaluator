//
//  cameraViewWithModel.swift
//  Gym
//
//  Created by Gianluca Latronico on 04/05/25.
//

import SwiftUI
import AVFoundation
import ReplayKit
import CoreML
import Photos
/*

struct CameraViewWithModel: UIViewControllerRepresentable {
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
        var modelPanca: MLModel?
        var modelSquat: MLModel?
        var modelStacco: MLModel?
        
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
            modelPanca = nil
            modelSquat = nil
            modelStacco = nil
            
            dismissAction?()
        }
        
        func loadModels() -> MLModel? {
            do {
                let config = MLModelConfiguration()
                config.computeUnits = .cpuOnly
                
                switch esercizioNome.lowercased() {
                case "panca":
                    if modelPanca == nil {
                        modelPanca = try _3d_cnn_model_panca(configuration: config).model
                        print("Modello Panca Caricato")
                    } else {
                        print("Modello Panca Già Caricato")
                    }
                    return modelPanca

                case "squat":
                    if modelSquat == nil {
                        modelSquat = try _3d_cnn_model_squat(configuration: config).model
                        print("Modello Squat Caricato")
                    } else {
                        print("Modello Squat Già Caricato")
                    }
                    return modelSquat

                case "stacco":
                    if modelStacco == nil {
                        modelStacco = try _3d_cnn_model_stacco(configuration: config).model
                        print("Modello Stacco Caricato")
                    } else {
                        print("Modello Stacco Già Caricato")
                    }
                    return modelStacco

                default:
                    print("Nessun modello")
                    return nil
                }
            } catch {
                print("Errore in caricamento")
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
                    
                    Task.detached { [weak self] in
                        do {
                            print("SONO ENTRATI UN TASK")
                            // Estrai i frame asincronamente
                            let frameArray = try await extractAllFrames(from: videoURL)
                            print("✅ Frame estratti: \(frameArray.count)")
                            guard let self = self else { return }
                            guard let model = await self.loadModels() else {
                                fatalError("❌ Modello non trovato")
                            }

                            let prediction = try await predictWith3DCNN( //in relatà è
                                frames: frameArray,
                                model: model,
                                inputName: "input_2",
                                targetSize: CGSize(width: 224, height: 224)
                            )
                            print("✅ Predizione completata: \(prediction)")
                            

                        if let outputValue = prediction.featureValue(for: "Identity")?.multiArrayValue?[0].floatValue {
                            if outputValue < 0.1 {
                                    await MainActor.run {
                                        let alert = UIAlertController(
                                            title: "Esercizio errato",
                                            message: "Hai eseguito un esercizio diverso da quello selezionato.",
                                            preferredStyle: .alert
                                        )
                                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                                        self.present(alert, animated: true)
                                        }
                                    }
                                }
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
}*/

/* CODICE CAMERAVIEW FUNZIONANTE
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
         var modelPanca: MLModel?
         var modelSquat: MLModel?
         var modelStacco: MLModel?
         
         override func viewDidLoad(){
             super.viewDidLoad()
             setupCamera()
             setupGrapich()
             requestCameraPermission()
             requestPhotoLibraryAccessIfNeeded()
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
             modelPanca = nil
             modelSquat = nil
             modelStacco = nil
             
             dismissAction?()
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

                 // Recupera il video registrato
                 getLastSavedVideo { url in
                     guard let videoURL = url else {
                         print("❌ Errore nel recupero del video")
                         return
                     }

                     print("📁 Video URL: \(videoURL)")
                     
                     let exerciseKey: String
                                 switch self.esercizioNome.lowercased() {
                                 case "panca": exerciseKey = "bench"
                                 case "squat": exerciseKey = "squat"
                                 case "stacco": exerciseKey = "deadlift"
                                 default:
                                     print("❌ Tipo di esercizio non valido")
                                     return
                                 }
                     DispatchQueue.global().async {
                         autoreleasepool() {
                             // Analisi completa (pose + postprocessing)
                             PostProcessingManager().analyze(videoURL: videoURL, forExercise: exerciseKey) { result in
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


CODICE PREDICTIONMODEL VECCHIO
 //
 //  modelPrediction.swift
 //  Gym
 //
 //  Created by Gianluca Latronico on 29/04/25.
 //
 import UIKit
 import CoreML
 import Accelerate
 import AVFoundation

 // MARK: - UIImage Extension

 extension UIImage {
     /// Resize the image to the given size
     func resized(to size: CGSize) -> UIImage? {
         UIGraphicsBeginImageContextWithOptions(size, false, self.scale)
         draw(in: CGRect(origin: .zero, size: size))
         let resized = UIGraphicsGetImageFromCurrentImageContext()
         UIGraphicsEndImageContext()
         return resized
     }

     /// Extract RGB pixel buffer [Float] normalized between 0 and 1
     func rgbPixelData(normalized: Bool = true) -> [Float]? {
         guard let cgImage = self.cgImage else { return nil }

         let width = cgImage.width
         let height = cgImage.height
         let bytesPerPixel = 4
         let bytesPerRow = bytesPerPixel * width
         let bitsPerComponent = 8

         var rawData = [UInt8](repeating: 0, count: height * bytesPerRow)
         guard let context = CGContext(
             data: &rawData,
             width: width,
             height: height,
             bitsPerComponent: bitsPerComponent,
             bytesPerRow: bytesPerRow,
             space: CGColorSpaceCreateDeviceRGB(),
             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
         ) else {
             return nil
         }

         context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

         var floatData = [Float]()
         floatData.reserveCapacity(width * height * 3)

         for y in 0..<height {
             for x in 0..<width {
                 let idx = y * bytesPerRow + x * bytesPerPixel
                 let r = Float(rawData[idx])
                 let g = Float(rawData[idx + 1])
                 let b = Float(rawData[idx + 2])
                 if normalized {
                     floatData.append(r / 255.0)
                     floatData.append(g / 255.0)
                     floatData.append(b / 255.0)
                 } else {
                     floatData.append(r)
                     floatData.append(g)
                     floatData.append(b)
                 }
             }
         }

         return floatData
     }
 }

 //MARK: Estrazione frame per passarli alla funzione videoToMLMultyArray
 func extractAllFrames(from videoURL: URL, batchSize: Int = 10) async throws -> [UIImage] {
     print("SONO ENTRATI UN EXTRACTFRAMES")
     let asset = AVURLAsset(url: videoURL)

     let duration = try await asset.load(.duration)
     print("📏 Durata video: \(duration.seconds) secondi")

     let durationInSeconds = CMTimeGetSeconds(duration)

     let tracks = try await asset.loadTracks(withMediaType: .video)
     print("🎞 Numero tracce video: \(tracks.count)")
     guard let track = tracks.first else {
         throw NSError(domain: "FrameExtraction", code: 1, userInfo: [NSLocalizedDescriptionKey: "Nessuna traccia video trovata."])
     }

     let fps = try await track.load(.nominalFrameRate)
     print("📹 FPS: \(fps)")

     let totalFrames = Int(durationInSeconds * Double(fps))

     let imageGenerator = AVAssetImageGenerator(asset: asset)
     imageGenerator.appliesPreferredTrackTransform = true

     var times: [NSValue] = []
     for i in 0..<totalFrames {
         let time = CMTime(seconds: Double(i) / Double(fps), preferredTimescale: 600)
         times.append(NSValue(time: time))
     }

     var allFrames: [UIImage] = []
     var index = 0

     while index < times.count && allFrames.count < 200 {
         let batch = Array(times[index..<min(index + batchSize, times.count)])

         let images: [UIImage] = try await withThrowingTaskGroup(of: UIImage.self) { group in
             for time in batch {
                 group.addTask {
                     return try await withCheckedThrowingContinuation { continuation in
                         imageGenerator.generateCGImagesAsynchronously(forTimes: [time]) { _, cgImage, _, _, error in
                             if let error = error {
                                     print("❌ Errore \(error.localizedDescription)")
                                 }
                             if let cgImage = cgImage {
                                 continuation.resume(returning: UIImage(cgImage: cgImage))
                             } else {
                                 continuation.resume(throwing: error ?? NSError(domain: "FrameExtraction", code: 2, userInfo: [NSLocalizedDescriptionKey: "Impossibile generare CGImage."]))
                             }
                         }
                     }
                 }
             }

             var batchImages: [UIImage] = []
             for try await image in group {
                 batchImages.append(image)
             }
             return batchImages
         }

         allFrames.append(contentsOf: images)
         index += batchSize
     }
     
     imageGenerator.cancelAllCGImageGeneration()
     return allFrames
 }


 // MARK: - Convert Batch to MLMultiArray

 /// Convert a batch of UIImages into MLMultiArray with shape (1, C, F, H, W)
 func videoToMLMultiArray(frames: [UIImage], targetSize: CGSize) throws -> MLMultiArray {
     print("SONO ENTRATI UN MULTUARRAY")
     let frameCount = frames.count
     let height = Int(targetSize.height)
     let width = Int(targetSize.width)
     let channels = 3

     let shape = [1, frameCount, height, width, channels] as [NSNumber]
     let array = try MLMultiArray(shape: shape, dataType: .float32)

     for f in 0..<frameCount {
         guard let resized = frames[f].resized(to: targetSize),
               let pixelData = resized.rgbPixelData() else {
             throw NSError(domain: "ConversionError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Frame conversion failed."])
         }

         var i = 0
         for y in 0..<height {
             for x in 0..<width {
                 let r = pixelData[i];     i += 1
                 let g = pixelData[i];     i += 1
                 let b = pixelData[i];     i += 1

                 array[[0, f, y, x, 0] as [NSNumber]] = NSNumber(value: r)
                 array[[0, f, y, x, 1] as [NSNumber]] = NSNumber(value: g)
                 array[[0, f, y, x, 2] as [NSNumber]] = NSNumber(value: b)
             }
         }
     }

     return array
 }


 // MARK: - Run Prediction

 /// Run the 3D CNN model prediction
 func predictWith3DCNN(
     frames: [UIImage],
     model: MLModel,
     inputName: String = "input_2",  // oppure il nome corretto se diverso
     targetSize: CGSize = CGSize(width: 224, height: 224)
 ) async throws -> MLFeatureProvider {
     print("SONO ENTRATI UN PREDICT")
     var framesToUse = Array(frames.prefix(200))  // Usa solo i primi 200 frame
     print("🎥 Numero di frame per la predizione: \(framesToUse.count)")

     // 🎞️ Converti i frame in MLMultiArray nel formato richiesto
     let inputArray = try videoToMLMultiArray(frames: framesToUse, targetSize: targetSize)
     print("Forma dell'input MLMultiArray: \(inputArray.shape)")
     print("✅ Input MLMultiArray creato con successo")

     // 🔁 Crea input del modello
     let input = try MLDictionaryFeatureProvider(dictionary: [inputName: inputArray])

     // 🧠 Esegui la prediction
     let result = try await model.prediction(from: input)
     framesToUse.removeAll(keepingCapacity: false)
     
     return result
 }



 
 
 
 */
