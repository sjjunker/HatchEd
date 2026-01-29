//
//  Portfolio.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/22/25.
//  Updated with assistance from Cursor (ChatGPT) on 11/7/25.
//
import SwiftUI

struct PortfolioView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel = PortfolioListViewModel()
    @State private var showingAddPortfolio = false
    @State private var selectedPortfolio: Portfolio?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 24) {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if viewModel.portfolios.isEmpty {
                        emptyStateView
                    } else {
                        portfoliosList
                    }
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.hatchEdCoralAccent)
                            .padding()
                    }
                }
                .padding()
                .padding(.bottom, 80)
            }
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
            Task { await viewModel.loadPortfolios() }
        }
        .refreshable {
            await viewModel.loadPortfolios()
        }
        .sheet(isPresented: $showingAddPortfolio) {
            AddPortfolioView(
                students: authViewModel.students,
                onSave: { _ in
                    Task { await viewModel.loadPortfolios() }
                }
            )
        }
        .onChange(of: showingAddPortfolio) { oldValue, newValue in
            if oldValue == true && newValue == false {
                Task { await viewModel.loadPortfolios() }
            }
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
            ForEach(viewModel.portfolios) { portfolio in
                PortfolioRow(portfolio: portfolio)
                    .onTapGesture { selectedPortfolio = portfolio }
            }
        }
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

