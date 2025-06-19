//
//  ContentView.swift
//  Gym
//
//  Created by Gianluca Latronico on 25/03/25.
//

import SwiftUI

struct ContentView: View {
    @State private var showCamera = false
    @State private var selectedExercise: String = ""
    @State private var showPopup = false
    @State private var popupMessage = ""

    @StateObject private var popup = ExercisePopupMessage()
    
    var body: some View {
        ZStack {
            if showCamera {
                
                CameraView(esercizio: selectedExercise, dismissAction: {
                    showCamera = false
                })
                    .edgesIgnoringSafeArea(.all)

                VStack {
                    Spacer()
                    
                }
            } else {
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
