//
//  ExportJsonKeystoreFileViewModel.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 10/12/21.
//

import Foundation
import AlphaWalletFoundation
import Combine

struct ExportJsonKeystoreFileViewModelInput {
    let willAppear: AnyPublisher<Void, Never>
    let export: AnyPublisher<Void, Never>
}

struct ExportJsonKeystoreFileViewModelOutput {
    let viewState: AnyPublisher<ExportJsonKeystoreFileViewModel.ViewState, Never>
    let error: AnyPublisher<String, Never>
    let fileUrl: AnyPublisher<URL, Never>
    let loadingState: AnyPublisher<ExportJsonKeystoreFileViewModel.ExportLoadingState, Never>
}

class ExportJsonKeystoreFileViewModel {
    private let fileManager = FileManager.default
    private let keystore: Keystore
    private let wallet: Wallet
    private let password: String
    private var exportedJson: String?

    init(keystore: Keystore, wallet: Wallet, password: String) {
        self.keystore = keystore
        self.wallet = wallet
        self.password = password
    }

    func transform(input: ExportJsonKeystoreFileViewModelInput) -> ExportJsonKeystoreFileViewModelOutput {
        let loadingState = PassthroughSubject<ExportLoadingState, Never>()

        let computeJson = input.willAppear
            .handleEvents(receiveOutput: { _ in loadingState.send(.beginLoading) })
            .flatMap { [password] in self.computeJsonKeystore(password: password) }
            .handleEvents(receiveOutput: { _ in loadingState.send(.endLoading) })
            .share()
            .eraseToAnyPublisher()

        let exportedJsonString = computeJson.compactMap { $0.value }
            .handleEvents(receiveOutput: { self.exportedJson = $0 })
            .prepend("")
            .eraseToAnyPublisher()

        let isActionButtonEnabled = Publishers.Merge(Just(false), computeJson.map { $0.error == nil })
            .eraseToAnyPublisher()

        let makeJsonFile = input.export
            .flatMap { _ in self.createJsonFile() }
            .share()
            .eraseToAnyPublisher()

        let error = Publishers.Merge(makeJsonFile.compactMap { $0.error?.localizedDescription }, computeJson.compactMap { $0.error?.localizedDescription })
            .eraseToAnyPublisher()

        let fileUrl = makeJsonFile.compactMap { $0.value }
            .eraseToAnyPublisher()

        let viewState = Publishers.CombineLatest(isActionButtonEnabled, exportedJsonString)
            .map { ExportJsonKeystoreFileViewModel.ViewState(isActionButtonEnabled: $0.0, exportedJsonString: $0.1) }
            .eraseToAnyPublisher()

        return .init(
            viewState: viewState,
            error: error,
            fileUrl: fileUrl,
            loadingState: loadingState.eraseToAnyPublisher())
    }

    private func createJsonFile() -> AnyPublisher<Result<URL, ExportToFileError>, Never> {
        guard let jsonString = exportedJson else { return .just(.failure(ExportToFileError.jsonNotFound)) }
        let fileName = "alphawallet_keystore_export_\(UUID().uuidString).json"
        let fileUrl = fileManager.temporaryDirectory.appendingPathComponent(fileName)
        do {
            guard let data = jsonString.data(using: .utf8) else { return .just(.failure(ExportToFileError.dataDecodeFailure)) }
            try data.write(to: fileUrl)

            return .just(.success(fileUrl))
        } catch {
            return .just(.failure(ExportToFileError.fileWriteFailure(error: error)))
        }
    }

    private func computeJsonKeystore(password: String) -> AnyPublisher<Result<String, KeystoreError>, Never> {
        if wallet.origin == .hd {
            let prompt = R.string.localizable.keystoreAccessKeyNonHdBackup()
            return keystore.exportRawPrivateKeyFromHdWallet0thAddressForBackup(forAccount: wallet.address, prompt: prompt, newPassword: password)
        } else {
            let prompt = R.string.localizable.keystoreAccessKeyNonHdBackup()
            return keystore.exportRawPrivateKeyForNonHdWalletForBackup(forAccount: wallet.address, prompt: prompt, newPassword: password)
        }
    }
}

extension ExportJsonKeystoreFileViewModel {
    enum ExportToFileError: Error {
        case jsonNotFound
        case dataDecodeFailure
        case fileWriteFailure(error: Error)
    }

    enum ExportLoadingState {
        case beginLoading
        case endLoading
    }

    struct ViewState {
        let buttonTitle: String = R.string.localizable.settingsAdvancedExportJSONKeystoreFilePasswordButtonPassword()
        let title: String = R.string.localizable.settingsAdvancedExportJSONKeystoreFileTitle()
        let isActionButtonEnabled: Bool
        let exportedJsonString: String
    }
}
