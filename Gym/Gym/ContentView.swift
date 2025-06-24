//
//  ContentView.swift
//  Gym
//
//  Created by Gianluca Latronico on 25/03/25.
//

import SwiftUI

struct ContentView: View {
    //Se mostrare la cameraView o no
    @State private var showCamera = false
    //Esercizio scelto
    @State private var selectedExercise: String = ""
    //mostrare o no popup sulle informazioni base
    @State private var showPopup = false
    //messaggio del popup
    @State private var popupMessage = ""
    //gestione popup
    @StateObject private var popup = ExercisePopupMessage()
    
    var body: some View {
        ZStack {
            //Mostrare o no la cameraView in base alla selezione
            if showCamera {
                
                CameraView(esercizio: selectedExercise, dismissAction: {
                    showCamera = false
                })
                    .edgesIgnoringSafeArea(.all)

                VStack {
                    Spacer()
                    
                }
            } else {
                //Schermata di home con nome, immagine e tre bottoni esercizi
                VStack(spacing: 20) {
                    
                    Text("Gym App")
                        .font(.largeTitle)
                        .fontWeight(.black)
                        .foregroundColor(Color.purple)
                        .bold()
                        .padding(.bottom, 50)
                    
                    Image("gymImage")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 20))

                    Button("PANCA") {
                        selectedExercise = "Panca"
                        handleExerciseTap(selectedExercise)
                    }
                    .buttonStyle(CustomButtonStyle())
                    .padding(.top, 50)
                    .onAppear{
                
                    }

                    Button("SQUAT") {
                        
                        selectedExercise = "Squat"
                        handleExerciseTap(selectedExercise)
                    }
                    .buttonStyle(CustomButtonStyle())
                    .padding(.top, 20)
                    .onAppear{
                
                    }

                    Button("STACCO") {
                      
                        selectedExercise = "Stacco"
                        handleExerciseTap(selectedExercise)
                    }
                    .buttonStyle(CustomButtonStyle())
                    .padding(.top, 20)
                    .onAppear{
                    
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(red: 0.1, green: 0.1, blue: 0.1).ignoresSafeArea())
                .alert("Info su \(selectedExercise)", isPresented: $showPopup) {
                    Button("Va bene") {
                        showCamera = true
                    }
                } message: {
                    Text(popupMessage)
                }
            }
        }
    }
    //Gestione bottone premuto, se prima volta mostra popup, altrimenti apre cameraView
    func handleExerciseTap(_ exercise: String) {
           selectedExercise = exercise
           let (shouldShow, message) = popup.shouldShowPopup(for: exercise)
           
           if shouldShow {
               popupMessage = message
               showPopup = true
           } else {
               showCamera = true
           }
       }
   }
    //stile bottoni
    struct CustomButtonStyle: ButtonStyle {
       func makeBody(configuration: Configuration) -> some View {
           configuration.label
               .padding()
               .fontWeight(.bold)
               .frame(width: 250)
               .background(Color.purple)
               .foregroundColor(Color(red: 75/255, green: 0/255, blue: 130/255))
               .clipShape(Capsule())
               .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
       }
   }

   #Preview {
       ContentView()
   }
