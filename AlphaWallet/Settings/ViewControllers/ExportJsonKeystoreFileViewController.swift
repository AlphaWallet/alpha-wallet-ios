//
//  ExportJsonKeystoreFileViewController.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 1/12/21.
//

import UIKit
import PromiseKit

@objc protocol ExportJsonKeystoreFileDelegate {
    func didExport(jsonData: String, in viewController: UIViewController)
    func didFinish()
    func didDismissFileController()
}

class ExportJsonKeystoreFileViewController: UIViewController {
    private let buttonTitle: String
    private let password: String
    private let viewModel: ExportJsonKeystoreFileViewModel
    private var exportedData: String = ""
    private var fileView: ExportJsonKeystoreFileView {
        return view as! ExportJsonKeystoreFileView
    }
    weak var fileDelegate: ExportJsonKeystoreFileDelegate?

    init(viewModel: ExportJsonKeystoreFileViewModel, buttonTitle: String, password: String) {
        self.viewModel = viewModel
        self.buttonTitle = buttonTitle
        self.password = password
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureController()
        DispatchQueue.main.async {
            self.configureContent()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if !isStillInNavigationStack() {
            fileDelegate?.didDismissFileController()
        }
    }

    override func loadView() {
        view = ExportJsonKeystoreFileView()
    }

    private func configureController() {
        navigationItem.title = R.string.localizable.settingsAdvancedExportJSONKeystoreFileTitle()
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(requestDoneAction(_:)))
        navigationItem.rightBarButtonItems = [doneButton]
        fileView.setButton(title: buttonTitle)
        fileView.addPasswordButtonTarget(self, action: #selector(requestExportAction(_:)))
    }

    private func configureContent() {
        fileView.disableButton()
        firstly {
            viewModel.computeJsonKeystore(password: password)
        }.done { jsonData in
            self.exportedData = jsonData
            self.fileView.set(content: jsonData)
            self.fileView.enableButton()
        }.catch { error in
            guard let navigationController = self.navigationController else { return }
            firstly {
                navigationController.displayErrorPromise(message: error.prettyError)
            }.done {
                navigationController.popViewController(animated: true)
            }.cauterize()
        }
    }

    @objc func requestExportAction(_ sender: UIButton?) {
         fileDelegate?.didExport(jsonData: exportedData, in: self)
    }

    @objc func requestDoneAction(_ sender: UIBarButtonItem) {
        fileDelegate?.didFinish()
    }
}
