//
//  Portfolio.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/22/25.
//  Updated with assistance from Cursor (ChatGPT) on 11/7/25.
//
import SwiftUI

struct PortfolioView: View {
    @EnvironmentObject private var signInManager: AppleSignInManager
    @State private var portfolios: [Portfolio] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingAddPortfolio = false
    @State private var selectedPortfolio: Portfolio?
    
    private let api = APIClient.shared
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 24) {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if portfolios.isEmpty {
                        emptyStateView
                    } else {
                        portfoliosList
                    }
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.hatchEdCoralAccent)
                            .padding()
                    }
                }
                .padding()
                .padding(.bottom, 80) // Space for floating button
            }
            
            // Floating Add Button
            Button {
                showingAddPortfolio = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2)
                    .foregroundColor(.hatchEdWhite)
                    .frame(width: 56, height: 56)
                    .background(Color.hatchEdAccent)
                    .clipShape(Circle())
                    .shadow(color: .hatchEdDarkGray.opacity(0.2), radius: 4, x: 0, y: 2)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
        }
        .navigationTitle("Portfolio")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await loadPortfolios()
            }
        }
        .refreshable {
            await loadPortfolios()
        }
        .sheet(isPresented: $showingAddPortfolio) {
            AddPortfolioView(
                students: signInManager.students,
                onSave: { portfolio in
                    Task {
                        await loadPortfolios()
                    }
                }
            )
        }
        .sheet(item: $selectedPortfolio) { portfolio in
            PortfolioDetailView(portfolio: portfolio)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder")
                .font(.system(size: 64))
                .foregroundColor(.hatchEdSecondaryText)
            Text("No portfolios yet")
                .font(.headline)
                .foregroundColor(.hatchEdSecondaryText)
            Text("Tap the + button to create a new portfolio")
                .font(.subheadline)
                .foregroundColor(.hatchEdSecondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private var portfoliosList: some View {
        VStack(spacing: 16) {
            ForEach(portfolios) { portfolio in
                PortfolioRow(portfolio: portfolio)
                    .onTapGesture {
                        selectedPortfolio = portfolio
                    }
            }
        }
    }
    
    @MainActor
    private func loadPortfolios() async {
        isLoading = true
        errorMessage = nil
        do {
            portfolios = try await api.fetchPortfolios()
        } catch {
            errorMessage = "Failed to load portfolios: \(error.localizedDescription)"
        }
        isLoading = false
    }
}

private struct PortfolioRow: View {
    let portfolio: Portfolio
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(.hatchEdWhite)
                    .font(.title3)
                    .padding(8)
                    .background(Color.hatchEdAccent)
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(portfolio.studentName)
                        .font(.headline)
                        .foregroundColor(.hatchEdText)
                    
                    Text(portfolio.designPattern.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.hatchEdSecondaryText)
                }
                
                Spacer()
                
                Text(portfolio.createdAt?.formatted(date: .abbreviated, time: .omitted) ?? "")
                    .font(.caption)
                    .foregroundColor(.hatchEdSecondaryText)
            }
            
            if !portfolio.snippet.isEmpty {
                Text(portfolio.snippet)
                    .font(.body)
                    .foregroundColor(.hatchEdText)
                    .lineLimit(3)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.hatchEdCardBackground)
                .shadow(color: Color.hatchEdAccent.opacity(0.15), radius: 4, x: 0, y: 2)
        )
    }
}

