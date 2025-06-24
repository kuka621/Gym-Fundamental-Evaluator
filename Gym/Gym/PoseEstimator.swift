//
//  PoseEstimator.swift
//  Gym
//
//  Created by Gianluca Latronico on 10/04/25.
//
import Vision
import CoreGraphics
import UIKit
/**
 Salvare i risultati delle analisi quali ripetizioni corrette svolte, ripetiizoni scorrette svolte, errori svolti e angoli (debug)
 */
struct PoseAnalysisResult {
    var repetitionCount: Int
    var incompleteCount: Int
    var errors: [String]
    var angles: [Double]
}
//Funzione per Panca
func processBench(from poses: [VNHumanBodyPoseObservation]) -> PoseAnalysisResult {
    var angles: [Double] = []
    let errors: [String] = []
    //variabili per rimozione secondi finali per evitare il conteggio di ripetizioni date dai movimenti
    //eseguiti per fermare la registrazione
    let frameRate = 30.0
    let secondsToDrop: Double = 2.5

    var correctCount = 0
    let incorrectCount = 0
    //Stati della FSM quali lokedOut = braccia distese, descending = fase di discesa e rising = fase di salita
    enum State {
        case lockedOut
        case descending
        case rising
    }

    var state: State = .lockedOut
    //Variabili usate per controlli sugli esercizi
    var minAngle: Double = 180.0
    var consecutiveLockoutFrames = 0
    let lockoutThreshold = 145.0
    let bottomThreshold = 90.0
    let lockoutStableFrames = 5
    let dropCount = Int(frameRate * secondsToDrop)
    let effectivePoses = poses.dropLast(dropCount)
    
    /*  Logica usata: se parte da lockout e scende sotto soglia allora passa a descending dove se angolo minore della soglia allora passa a rising e in questo stato superata solgia di lockout ripetizione viene contata
        Nessun controllo sulla correttezza dell'esecuzione per via di problematiche di rilevazine keypoint
     */
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
        }
    }

    return PoseAnalysisResult(
        repetitionCount: correctCount,
        incompleteCount: incorrectCount,
        errors: errors,
        angles: angles
    )
}
//Funzione per stacco
func processDeadlift(from poses: [VNHumanBodyPoseObservation]) -> PoseAnalysisResult {
    var angles: [Double] = []
    var errors: [String] = []
    var correctCount = 0
    var incorrectCount = 0
    //variabili per rimozione secondi finali per evitare il conteggio di ripetizioni date dai movimenti
    //eseguiti per fermare la registrazione
    let frameRate = 30.0
    let secondsToDrop: Double = 1.5
    let dropCount = Int(frameRate * secondsToDrop)
    let effectivePoses = poses.dropLast(dropCount)
    //Stati della FSM quali idle = posizione inziale, descending = fase di discesa e rising = fase di salita
    enum State {
        case idle
        case descending
        case rising
    }
    //Variabili usate per controlli sugli esercizi
    var state: State = .idle
    var hasReachedDepth = false
    var repAlreadyCounted = false
    var minAngle: Double = 180.0
    let validDepth = 95.0
    let lockoutThreshold = 140.0
    
    /*  Logica usata: si parte da idle poisizione iniziale, se l'angolo scende sotto la soglia si passa a descending dove viene reigistrato l'angolo minimo raggiunto e controllo sulla soglia di profondità se valida passaggio a rising dove vengono conteggiate ripetizioni corrette e scorrette
     */
    for pose in effectivePoses {
        guard let angle = calculateHipAngle(from: pose) else { continue }
        angles.append(angle)
        
        switch state {
        case .idle:
            if angle < validDepth {
                state = .descending
                hasReachedDepth = true
                minAngle = angle
                repAlreadyCounted = false
            }
            
        case .descending:
            if angle < minAngle {
                minAngle = angle
            }
            if angle >= validDepth {
                state = .rising
            }
            
        case .rising:
            if angle >= lockoutThreshold {
                if hasReachedDepth && !repAlreadyCounted {
                    if minAngle < validDepth {
                        correctCount += 1
                    } else {
                        incorrectCount += 1
                        errors.append("Deadlift troppo corto: scendi di più")
                    }
                    repAlreadyCounted = true
                }
                state = .idle
                
            } else if angle < validDepth {
                if hasReachedDepth && !repAlreadyCounted {
                    incorrectCount += 1
                    errors.append("Non sei salito abbastanza")
                    repAlreadyCounted = true
                }
                state = .descending
                hasReachedDepth = true
                minAngle = angle
                repAlreadyCounted = false
            }
        }
    }
    
    return PoseAnalysisResult(
        repetitionCount: correctCount,
        incompleteCount: incorrectCount,
        errors: errors,
        angles: angles
    )
}
//Funzione squat
func processSquat(from poses: [VNHumanBodyPoseObservation]) -> PoseAnalysisResult {
    var angles: [Double] = []
    var errors: [String] = []

    var correctCount = 0
    var incorrectCount = 0
    
    //Stati della FSM quali standing = in piedi, descending = fase di discesa e rising = fase di salita
    enum State {
        case standing
        case descending
        case rising
    }
    //Variabili usate per controlli sugli esercizi
    var state: State = .standing
    var minAngle: Double = 180.0
    var isDescending = false
    var repAlreadyCounted = false
    let upThreshold = 150.0
    let validDepth = 110.0
    /**
     Logica usata: Se angolo scende sotto la soglia superiore allora passa a fase descending dove viene salvato angolo minimo e se si supera l'angolo minimo di 5 allora parte fase rising dove vengono salvate riperizioni corrette e scorrette
     */
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
                if isDescending && !repAlreadyCounted {
                    if minAngle < validDepth {
                        correctCount += 1
                    } else {
                        incorrectCount += 1
                        errors.append("Squat troppo alto, scendi di più")
                    }
                    repAlreadyCounted = true
                }
                isDescending = false
                state = .standing
            } else {
                repAlreadyCounted = false
            }
        }
    }

    return PoseAnalysisResult(
        repetitionCount: correctCount,
        incompleteCount: incorrectCount,
        errors: errors,
        angles: angles
    )
}

//Funzione per calcolo angolo anca ginocchia e caviglia
func calculateKneeAngle(from pose: VNHumanBodyPoseObservation) -> Double? {
    guard let hip = try? pose.recognizedPoint(.leftHip),
          let knee = try? pose.recognizedPoint(.leftKnee),
          let ankle = try? pose.recognizedPoint(.leftAnkle),
          hip.confidence > 0.3, knee.confidence > 0.3, ankle.confidence > 0.3 else {
        return nil
    }

    return angleBetween(p1: hip.location, p2: knee.location, p3: ankle.location)
}
//Funzione per calcolare angolo spalla, gomito e polso sia sinistro sia destro per migliore valutazione
func calculateArmAngle(from observation: VNHumanBodyPoseObservation) -> Double? {
    func point(_ jointName: VNHumanBodyPoseObservation.JointName) -> VNRecognizedPoint? {
        return try? observation.recognizedPoint(jointName)
    }

    guard let rShoulder = point(.rightShoulder), let rElbow = point(.rightElbow), let rWrist = point(.rightWrist),
          let lShoulder = point(.leftShoulder), let lElbow = point(.leftElbow), let lWrist = point(.leftWrist),
          rShoulder.confidence > 0.3, rElbow.confidence > 0.3, rWrist.confidence > 0.3,
          lShoulder.confidence > 0.3, lElbow.confidence > 0.3, lWrist.confidence > 0.3 else {
        return nil
    }

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
    let average = (rAngle + lAngle) / 2
    return average
}
//Funzione per calcolare angolo spalla anca e ginocchio
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

//Funzione per calcolare angolo tra tre punti
func angleBetween(p1: CGPoint, p2: CGPoint, p3: CGPoint) -> Double {
    let v1 = CGVector(dx: p1.x - p2.x, dy: p1.y - p2.y)
    let v2 = CGVector(dx: p3.x - p2.x, dy: p3.y - p2.y)
    let dot = v1.dx * v2.dx + v1.dy * v2.dy
    let mag1 = sqrt(v1.dx * v1.dx + v1.dy * v1.dy)
    let mag2 = sqrt(v2.dx * v2.dx + v2.dy * v2.dy)
    let angle = acos(dot / (mag1 * mag2))
    return angle * 180 / Double.pi
}
