import UIKit
import AVFoundation
import Vision
import Foundation
import CoreGraphics
import CoreML

typealias Keypoints = [VNHumanBodyPoseObservation.JointName: CGPoint?]

// MARK: - Estrai frames da un video (compatibile con iOS 18+)
func extractAllFrames(from videoURL: URL, frameCount: Int = 240) async -> [CGImage] {
    var cgImages: [CGImage] = []
    
    let asset = AVURLAsset(url: videoURL)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true

    do {
        let duration = try await asset.load(.duration)
        let totalSeconds = CMTimeGetSeconds(duration)
        print("Ecco i  sevondi: \(totalSeconds)")

        for i in 0..<frameCount {
            let time = CMTimeMakeWithSeconds(Double(i) * totalSeconds / Double(frameCount), preferredTimescale: 600)
            let cgImage = try await generateCGImageAsync(generator: generator, for: time)
            cgImages.append(cgImage) // Usa direttamente CGImage
        }
    } catch {
        print("Errore durante l’estrazione dei frame: \(error)")
    }

    return cgImages
}

func generateCGImageAsync(generator: AVAssetImageGenerator, for time: CMTime) async throws -> CGImage {
    return try await withCheckedThrowingContinuation { continuation in
        generator.generateCGImageAsynchronously(for: time) { cgImage, actualTime, error in
            if let error = error {
                continuation.resume(throwing: error)
            } else if let cgImage = cgImage {
                continuation.resume(returning: cgImage)
            } else {
                continuation.resume(throwing: NSError(domain: "CGImageError", code: -1, userInfo: nil))
            }
        }
    }
}



// MARK: - Estrai keypoint da una singola immagine (18 valori)
func extractPoseKeypoints(from cgImage: CGImage) -> [Float]? {
    let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    let request = VNDetectHumanBodyPoseRequest()
    
    do {
        try requestHandler.perform([request])
        guard let observation = request.results?.first as? VNHumanBodyPoseObservation else { return nil }
        let recognizedPoints = try observation.recognizedPoints(.all)
        
        // Prendi solo i keypoint che ti servono
        let keypointNames: [VNHumanBodyPoseObservation.JointName] = [
            .nose, .neck,
            .rightShoulder, .rightElbow, .rightWrist,
            .leftShoulder, .leftElbow, .leftWrist,
            .rightHip, .rightKnee, .rightAnkle,
            .leftHip, .leftKnee, .leftAnkle,
            .rightEye, .leftEye,
            .rightEar, .leftEar
        ]
        
        var keypoints: [Float] = []
        for name in keypointNames {
            if let point = recognizedPoints[name], point.confidence > 0.3 {
                keypoints.append(Float(point.location.x))
                keypoints.append(Float(point.location.y))
                keypoints.append(Float(point.confidence))
                
            } else {
                keypoints.append(0.0)
                keypoints.append(0.0)
                keypoints.append(0.0)
            }
        }
        
        return keypoints
    } catch {
        print("Errore nell’analisi della posa: \(error)")
        return nil
    }
}

// MARK: - Predizione con modello Core ML
func predictWithPoseArray(
    poseSequences: [[[Float]]], // [210][3][18]
    model: MLModel,
    inputName: String = "poses"
) throws -> MLFeatureProvider {
    let multiArray = try MLMultiArray(shape: [240, 3, 18] as [NSNumber], dataType: .float32)
    
    for i in 0..<240 {
        for j in 0..<3 {
            for k in 0..<18 {
                let value = poseSequences[i][j][k]
                let index = i * 3 * 18 + j * 18 + k
                multiArray[index] = NSNumber(value: value)
            }
        }
    }
    
    let input = try MLDictionaryFeatureProvider(dictionary: [inputName: multiArray])
    let result = try model.prediction(from: input)
    return result
}

// MARK: - Funzione principale per analizzare un video
func analyzeVideoWith3DCNN(videoURL: URL, model: MLModel) async throws -> (label: String, probabilities: [String: Double]) {
    let cgFrames = await extractAllFrames(from: videoURL)
    guard cgFrames.count == 240 else {
        throw NSError(domain: "FrameExtractionError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Non sono stati estratti 240 frame."])
    }
    print("Numero di frame estratti: \(cgFrames.count)")
    var poseArray: [[[Float]]] = []

    for i in 0..<240 {
        guard let keypoints = extractPoseKeypoints(from: cgFrames[i]) else {
            print("⚠️ Nessuna posa rilevata al frame \(i), inserisco zeri.")
            let emptyFramePose = Array(repeating: Array(repeating: Float(0.0), count: 18), count: 3)
            poseArray.append(emptyFramePose)
            continue
        }

        var framePose: [[Float]] = Array(repeating: Array(repeating: 0.0, count: 18), count: 3)
        for j in 0..<18 {
            framePose[0][j] = keypoints[j * 3]
            framePose[1][j] = keypoints[j * 3 + 1]
            framePose[2][j] = keypoints[j * 3 + 2]
        }

        poseArray.append(framePose)
    }

    let prediction = try predictWithPoseArray(
        poseSequences: poseArray,
        model: model,
        inputName: "poses"
    )

    guard let probDict = prediction.featureValue(for: "labelProbabilities")?.dictionaryValue as? [String: Double],
          let label = prediction.featureValue(for: "label")?.stringValue else {
        throw NSError(domain: "PredictionError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Impossibile estrarre la label o le probabilità."])
    }

    return (label, probDict)
}

