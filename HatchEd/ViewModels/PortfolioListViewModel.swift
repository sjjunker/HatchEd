//
//  PortfolioListViewModel.swift
//  HatchEd
//
//  MVVM: ViewModel for portfolio list screen.
//

import Foundation
import SwiftUI

@MainActor
final class PortfolioListViewModel: ObservableObject {
    @Published private(set) var portfolios: [Portfolio] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let api = APIClient.shared

    func loadPortfolios() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let fetched = try await api.fetchPortfolios()
            portfolios = fetched
        } catch {
            if error is CancellationError {
                return
            }
            let message = error.localizedDescription.lowercased()
            if message == "cancelled" || message == "canceled" {
                return
            }
            print("[PortfolioList] Error loading portfolios: \(error)")
            errorMessage = "Failed to load portfolios: \(error.localizedDescription)"
        }
    }
}
