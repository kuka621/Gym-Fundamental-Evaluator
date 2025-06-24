//
//  infoPopup.swift
//  Gym
//
//  Created by Gianluca Latronico on 29/04/25.
//

import SwiftUI
//Classe per alert con informazioni sulla visualizzazione popup con mantenimento in memoria
class ExercisePopupMessage: ObservableObject {
    @AppStorage("hasSeenBenchPopup") var hasSeenBenchPopup = false
    @AppStorage("hasSeenSquatPopup") var hasSeenSquatPopup = false
    @AppStorage("hasSeenDeadliftPopup") var hasSeenDeadliftPopup = false

    func shouldShowPopup(for exercise: String) -> (Bool, String) {
        switch exercise {
        case "Panca":
            if !hasSeenBenchPopup {
                hasSeenBenchPopup = true
                let popupMessage = "Benvenuto, consiglio una ripresa dell'esercizio da dietro in modo da permettere un'analisi migliore. Una volta premuto il pulsante di registrazione partirà un countdown di 10 secondi per permettere il posizionamento, finiti i quali verrà richiesto, solo per la prima volta, il permesso di registrare lo schermo. Finito di registrare il video si prega di aspettare qualche secondo per poter visualizzare correttamente la schermata di recap"
                return (true, popupMessage)
            }
        case "Squat":
            if !hasSeenSquatPopup {
                hasSeenSquatPopup = true
                let popupMessage = "Benvenuto, consiglio una ripresa dell'esercizio frontale in modo da permettere un'analisi migliore. Una volta premuto il pulsante di registrazione partirà un countdown di 10 secondi per permettere il posizionamento, finiti i quali verrà richiesto, solo per la prima volta, il permesso di registrare lo schermo. Finito di registrare il video si prega di aspettare qualche secondo per poter visualizzare correttamente la schermata di recap."
                return (true, popupMessage)
            }
        case "Stacco":
            if !hasSeenDeadliftPopup {
                hasSeenDeadliftPopup = true
                let popupMessage = "Benvenuto, consiglio una ripresa dell'esercizio frontale in modo da permettere un'analisi migliore. Una volta premuto il pulsante di registrazione partirà un countdown di 10 secondi per permettere il posizionamento, finiti i quali verrà richiesto, solo per la prima volta, il permesso di registrare lo schermo. Finito di registrare il video si prega di aspettare qualche secondo per poter visualizzare correttamente la schermata di recap."
                return (true, popupMessage)
            }
        default:
            break
        }
        return (false, "")
    }
}
