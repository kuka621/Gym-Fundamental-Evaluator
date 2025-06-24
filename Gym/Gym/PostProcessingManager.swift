//
//  PostProcessingManager.swift
//  Gym
//
//  Created by Gianluca Latronico on 11/04/25.
//
import AVFoundation
import Vision
import CoreGraphics
import UIKit

class PostProcessingManager {
    //Istanza globale
    static let shared = PostProcessingManager()
    /**
     Estrae i frame dal video usando VNDetectHumanBodyPoseRequest, dopodiche passa i risultati alla funzione delle pose in base all'esercizio selezionato e restituendo il risultato dell'analisi
     */
    func analyze(videoURL: URL, forExercise exerciseType: String, completion: @escaping (PoseAnalysisResult) -> Void) {
        var poses: [VNHumanBodyPoseObservation] = []
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNSequenceRequestHandler()

        extractAndProcessFrames(from: videoURL, batchSize: 30) { frames in
            for image in frames {
                autoreleasepool {
                    guard let cgImage = image.cgImage else { return }

                    do {
                        try handler.perform([request], on: cgImage)
                        if let result = request.results?.first as? VNHumanBodyPoseObservation {
                            poses.append(result)
                        }
                    } catch {
                        print("Errore analisi pose: \(error.localizedDescription)")
                    }
                }
            }
        } completion: {
            let result: PoseAnalysisResult
            switch exerciseType {
            case "panca":
                result = processBench(from: poses)
            case "stacco":
                result = processDeadlift(from: poses)
            case "squat":
                result = processSquat(from: poses)
            default:
                result = PoseAnalysisResult(
                    repetitionCount: 0,
                    incompleteCount: 0,
                    errors: ["Esercizio non riconosciuto"],
                    angles: []
                )
            }

            completion(result)
        }
    }
    //Estrae i frame dal video dividendoli in batch da 30
    func extractAndProcessFrames(
        from videoURL: URL,
        batchSize: Int = 30,
        processBatch: @escaping ([UIImage]) -> Void,
        completion: @escaping () -> Void
    ) {
        let asset = AVURLAsset(url: videoURL)
        
        Task {
            do {
                let duration = try await asset.load(.duration)
                let durationInSeconds = CMTimeGetSeconds(duration)
                print("Durata video: \(durationInSeconds) secondi")
                
                let tracks = try await asset.loadTracks(withMediaType: .video)
                guard let track = tracks.first else {
                    print("Nessuna traccia video trovata.")
                    completion()
                    return
                }

                let fps = try await track.load(.nominalFrameRate)
                print("FPS: \(fps)")
                
                let totalFrames = Int(durationInSeconds * Double(fps))
                let imageGenerator = AVAssetImageGenerator(asset: asset)
                imageGenerator.appliesPreferredTrackTransform = true
                imageGenerator.requestedTimeToleranceAfter = .zero
                imageGenerator.requestedTimeToleranceBefore = .zero
                
                var times: [NSValue] = []
                for i in 0..<totalFrames {
                    let time = CMTime(seconds: Double(i) / Double(fps), preferredTimescale: CMTimeScale(fps))
                    times.append(NSValue(time: time))
                }
                
                var index = 0
                while index < times.count {
                    let batch = Array(times[index..<min(index + batchSize, times.count)])
                    let batchGroup = DispatchGroup()
                    var batchImages: [UIImage] = []
                    
                    for time in batch {
                        batchGroup.enter()
                        imageGenerator.generateCGImagesAsynchronously(forTimes: [time]) { requestedTime, cgImage, actualTime, _, error in
                            if let cgImage = cgImage {
                                let image = UIImage(cgImage: cgImage)
                                batchImages.append(image)
                            }
                            /*// else if let error = error {
                                //let seconds = requestedTime.seconds
                                //print("⚠️ Errore frame @\(String(format: "%.2f", seconds))s: \(error.localizedDescription)")
                            //}*/
                            batchGroup.leave()
                        }
                    }
                    
                    await withCheckedContinuation { continuation in
                        batchGroup.notify(queue: .main) {
                            autoreleasepool {
                                processBatch(batchImages)
                            }
                            continuation.resume()
                        }
                    }
                    index += batchSize
                }
                
                print("Tutti i frame processati.")
                completion()
                
            } catch {
                print("Errore durante l'estrazione: \(error.localizedDescription)")
                completion()
            }
        }
    }
}
