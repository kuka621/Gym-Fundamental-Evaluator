//
//  RecapView.swift
//  Gym
//
//  Created by Gianluca Latronico on 29/04/25.
//

import SwiftUI
//View sul recap del conteggio ripetizioni con corrette e scorrette e visualizzazione errori
struct RecapView: View {
    let result: PoseAnalysisResult
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 10) {
            Text("RIEPILOGO ESERCIZIO")
                .font(.largeTitle)
                .bold()
                .foregroundColor(.purple)

            Spacer().frame(height: 10)
            
            Image("recapImg")
                .resizable()
                .scaledToFit()
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            
            Spacer().frame(height: 15)

            VStack(spacing: 20) {
                Text("RIPETIZIONI TOTALI: \(result.repetitionCount + result.incompleteCount)")
                Text("RIPETIZIONI CORRETTE: \(result.repetitionCount)")
                Text("RIPETIZIONI SCORRETTE: \(result.incompleteCount)")

                if !result.errors.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ERRORI RISCONTRATI:")
                            .underline()
                        ForEach(Array(result.errors.enumerated()), id: \.offset) { index, error in
                            Text("• \(error)")
                        }
                    }
                }
            }
            .font(.title3)
            .foregroundColor(.purple)

            Spacer()

            Button(action: {
                dismiss()
            }) {
                Text("Chiudi")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.purple)
                    .foregroundColor(Color(red: 75/255, green: 0/255, blue: 130/255))
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color(red: 0.25, green: 0.25, blue: 0.25).ignoresSafeArea())
    }
}


