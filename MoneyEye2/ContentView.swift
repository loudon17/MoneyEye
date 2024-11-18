//
//  ContentView.swift
//  MoneyEye2
//
//  Created by Luigi Donnino on 18/11/24.
//
import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false // Tracks onboarding completion

    var body: some View {
        if hasCompletedOnboarding {
            CameraViewRepresentable() // Main screen is the live camera once onboarding is complete
        } else {
            TermsScreen(hasCompletedOnboarding: $hasCompletedOnboarding) // Show onboarding screens if not completed
        }
    }
}

struct TermsScreen: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var navigateToWelcomeScreen = false

    var body: some View {
        NavigationStack {
            VStack {
                ZStack {
                    Color(red: 1/255, green: 21/255, blue: 48/255)
                    Text("AGREEMENTS TERMS")
                        .font(.system(size: 24))
                        .fontWeight(.heavy)
                        .foregroundColor(Color.white)
                        .offset(y: 20)
                }
                .frame(maxHeight: 120)
                .ignoresSafeArea()

                ZStack {
                    Text("Our app does its best to correctly recognize coins and banknotes. However, this app doesn't recognise counterfeit money and errors may occur. By using this app, you acknowledge and agree that we decline all liability for any damage caused to you or any third party by misidentification of coins or banknotes. Tap anywhere to accept the terms and start using the app.")
                        .font(Font.custom("Helvetica", size: 20))
                        .fontWeight(.heavy)
                        .foregroundColor(Color(red: 1/255, green: 21/255, blue: 48/255))
                        .padding(.horizontal, 10)
                }
                .padding()
                
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                navigateToWelcomeScreen = true
            }
            .navigationDestination(isPresented: $navigateToWelcomeScreen) {
                WelcomeScreen(hasCompletedOnboarding: $hasCompletedOnboarding)
            }
        }
    }
}

struct WelcomeScreen: View {
    @Binding var hasCompletedOnboarding: Bool

    var body: some View {
        VStack {
            ZStack {
                Color(red: 1/255, green: 21/255, blue: 48/255)
                Text("WELCOME")
                    .font(.system(size: 24))
                    .fontWeight(.heavy)
                    .foregroundColor(Color.white)
                    .offset(y: 20)
            }
            .frame(maxHeight: 120)
            .ignoresSafeArea()

            ZStack {
                Text("This app will help you recognize currency. Point the phone’s camera at the currency and listen, see or feel its value. Tap anywhere to start using the app.")
                    .font(Font.custom("Helvetica", size: 20))
                    .fontWeight(.heavy)
                    .foregroundColor(Color(red: 1/255, green: 21/255, blue: 48/255))
                    .padding(.horizontal, 10)
            }
            .padding()
            
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            hasCompletedOnboarding = true // Set the flag to indicate onboarding is complete
        }
        .navigationBarBackButtonHidden(true)
    }
}
