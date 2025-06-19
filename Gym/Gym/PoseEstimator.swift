//
//  PoseEstimator.swift
//  Gym
//
//  Created by Gianluca Latronico on 10/04/25.
//
import Vision
import CoreGraphics
import UIKit

struct PoseAnalysisResult {
    var repetitionCount: Int
    var incompleteCount: Int
    var errors: [String]
    var angles: [Double]
}

func processBench(from poses: [VNHumanBodyPoseObservation]) -> PoseAnalysisResult {
    var angles: [Double] = []
    let errors: [String] = []
    let frameRate = 30.0 // o calcolato dinamicamente se disponibile
    let secondsToDrop: Double = 3.0 // per panca, oppure 2.0 per stacco

    var correctCount = 0
    let incorrectCount = 0

    enum State {
        case lockedOut
        case descending
        case bottom
        case rising
    }

    var state: State = .lockedOut
    var minAngle: Double = 180.0
    var consecutiveLockoutFrames = 0
    let lockoutThreshold = 145.0
    let bottomThreshold = 90.0
    let lockoutStableFrames = 5
    let dropCount = Int(frameRate * secondsToDrop)
    let effectivePoses = poses.dropLast(dropCount)
    

    for pose in effectivePoses {
        guard let angle = calculateArmAngle(from: pose) else { continue }
        angles.append(angle)

        switch state {
        case .lockedOut:
            if angle < lockoutThreshold {
                state = .descending
                minAngle = angle
            } else {
                consecutiveLockoutFrames += 1
                if consecutiveLockoutFrames >= lockoutStableFrames {
                    // Stabile in lockout: sicuro pronto
                    consecutiveLockoutFrames = 0
                }
            }

        case .descending:
            if angle < minAngle {
                minAngle = angle
            }
            if angle <= bottomThreshold {
                state = .rising
            }

        case .rising:
            if angle > lockoutThreshold {
                correctCount += 1
                state = .lockedOut
                minAngle = 180.0
            }

        default:
            break
        }
    }

    return PoseAnalysisResult(
        repetitionCount: correctCount,
        incompleteCount: incorrectCount,
        errors: errors,
        angles: angles
    )
}

func processDeadlift(from poses: [VNHumanBodyPoseObservation]) -> PoseAnalysisResult {
    var angles: [Double] = []
    var errors: [String] = []
    var correctCount = 0
    var incorrectCount = 0

    enum State {
        case idle
        case lowering
        case rising
    }

    var state: State = .idle
    var hasReachedDepth = false
    var alreadyCountedThisRep = false

    let validDepth = 95.0
    let lockoutThreshold = 140.0

    for (_, pose) in poses.enumerated() {
        guard let angle = calculateHipAngle(from: pose) else { continue }
        angles.append(angle)

        switch state {
        case .idle:
            if angle < validDepth {
                state = .lowering
                hasReachedDepth = true
                alreadyCountedThisRep = false
            }

        case .lowering:
            if angle >= validDepth {
                state = .rising
            }

        case .rising:
            if angle >= lockoutThreshold {
                if hasReachedDepth && !alreadyCountedThisRep {
                    correctCount += 1
                    alreadyCountedThisRep = true
                }
                state = .idle
            } else if angle < validDepth {
                if hasReachedDepth && !alreadyCountedThisRep {
                    incorrectCount += 1
                    errors.append("Ripetizione incompleta: non sei arrivato abbastanza in alto")
                    alreadyCountedThisRep = true
                }
                state = .lowering // torna giù
            }
        }
    }

    // Non contiamo l’ultima come errore se non è stata completata
    if state == .rising && (angles.last ?? 180) < lockoutThreshold && !alreadyCountedThisRep {
        // Non fare nulla
    }

    return PoseAnalysisResult(
        repetitionCount: correctCount,
        incompleteCount: incorrectCount,
        errors: errors,
        angles: angles
    )
}


func processSquat(from poses: [VNHumanBodyPoseObservation]) -> PoseAnalysisResult {
    var angles: [Double] = []
    var errors: [String] = []

    var correctCount = 0
    var incorrectCount = 0

    enum State {
        case standing
        case descending
        case bottom
        case rising
    }

    var state: State = .standing
    var minAngle: Double = 180.0
    var isDescending = false

    let upThreshold = 150.0       // Considerato posizione in piedi
    let validDepth = 110.0         // Sotto questo valore è un buon squat

    for pose in poses {
        guard let angle = calculateKneeAngle(from: pose) else { continue }
        angles.append(angle)

        switch state {
        case .standing:
            if angle < upThreshold {
                state = .descending
                minAngle = angle
                isDescending = true
            }

        case .descending:
            if angle < minAngle {
                minAngle = angle
            }
            if angle >= minAngle + 5 {
                state = .rising
            }

        case .rising:
            if angle > upThreshold {
                if isDescending {
                    if minAngle < validDepth {
                        correctCount += 1
                    } else {
                        incorrectCount += 1
                        errors.append("Squat troppo alto, scendi di più")
                    }
                    isDescending = false
                    state = .standing
                }
            }

        default:
            break
        }
    }

    return PoseAnalysisResult(
        repetitionCount: correctCount,
        incompleteCount: incorrectCount,
        errors: errors,
        angles: angles
    )
}


func calculateKneeAngle(from pose: VNHumanBodyPoseObservation) -> Double? {
    guard let hip = try? pose.recognizedPoint(.leftHip),
          let knee = try? pose.recognizedPoint(.leftKnee),
          let ankle = try? pose.recognizedPoint(.leftAnkle),
          hip.confidence > 0.3, knee.confidence > 0.3, ankle.confidence > 0.3 else {
        return nil
    }

    return angleBetween(p1: hip.location, p2: knee.location, p3: ankle.location)
}

func calculateArmAngle(from observation: VNHumanBodyPoseObservation) -> Double? {
    func point(_ jointName: VNHumanBodyPoseObservation.JointName) -> VNRecognizedPoint? {
        return try? observation.recognizedPoint(jointName)
    }

    // Prende i punti necessari per entrambi i lati
    guard let rShoulder = point(.rightShoulder), let rElbow = point(.rightElbow), let rWrist = point(.rightWrist),
          let lShoulder = point(.leftShoulder), let lElbow = point(.leftElbow), let lWrist = point(.leftWrist),
          rShoulder.confidence > 0.3, rElbow.confidence > 0.3, rWrist.confidence > 0.3,
          lShoulder.confidence > 0.3, lElbow.confidence > 0.3, lWrist.confidence > 0.3 else {
        return nil
    }

    // Converte in CGPoint
    let rAngle = angleBetween(
        p1: CGPoint(x: rShoulder.x, y: rShoulder.y),
        p2: CGPoint(x: rElbow.x, y: rElbow.y),
        p3: CGPoint(x: rWrist.x, y: rWrist.y)
    )

    let lAngle = angleBetween(
        p1: CGPoint(x: lShoulder.x, y: lShoulder.y),
        p2: CGPoint(x: lElbow.x, y: lElbow.y),
        p3: CGPoint(x: lWrist.x, y: lWrist.y)
    )

    // Media dei due angoli
    let average = (rAngle + lAngle) / 2
    return average
}

func calculateHipAngle(from pose: VNHumanBodyPoseObservation) -> Double? {
    guard
        let shoulder = try? pose.recognizedPoint(.rightShoulder),
        let hip = try? pose.recognizedPoint(.rightHip),
        let knee = try? pose.recognizedPoint(.rightKnee),
        shoulder.confidence > 0.3,
        hip.confidence > 0.3,
        knee.confidence > 0.3
    else {
        return nil
    }

    return angleBetween(p1: shoulder.location, p2: hip.location, p3: knee.location)
}


func angleBetween(p1: CGPoint, p2: CGPoint, p3: CGPoint) -> Double {
    let v1 = CGVector(dx: p1.x - p2.x, dy: p1.y - p2.y)
    let v2 = CGVector(dx: p3.x - p2.x, dy: p3.y - p2.y)
    let dot = v1.dx * v2.dx + v1.dy * v2.dy
    let mag1 = sqrt(v1.dx * v1.dx + v1.dy * v1.dy)
    let mag2 = sqrt(v2.dx * v2.dx + v2.dy * v2.dy)
    let angle = acos(dot / (mag1 * mag2))
    return angle * 180 / Double.pi
}
