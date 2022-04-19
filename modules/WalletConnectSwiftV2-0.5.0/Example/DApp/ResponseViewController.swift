
import Foundation
import WalletConnect
import UIKit

class ResponseViewController: UIViewController {
    let response: Response
    private let responseView = {
        ResponseView()
    }()
    
    init(response: Response) {
        self.response = response
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        view = responseView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let record = ClientDelegate.shared.client.getSessionRequestRecord(id: response.result.id)!
        switch response.result {
        case  .response(let response):
            responseView.nameLabel.text = "Received Response\n\(record.request.method)"
            responseView.descriptionLabel.text = try! response.result.get(String.self).description
        case .error(let error):
            responseView.nameLabel.text = "Received Error\n\(record.request.method)"
            responseView.descriptionLabel.text = error.error.message
        }
        responseView.dismissButton.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)
    }
    
    @objc func dismissSelf() {
        dismiss(animated: true, completion: nil)
    }
}


final class ResponseView: UIView {

    let nameLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 17.0, weight: .heavy)
        return label
    }()
    
    let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()
    
    let dismissButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Dismiss", for: .normal)
        button.backgroundColor = .systemBlue
        button.tintColor = .white
        button.layer.cornerRadius = 8
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17.0, weight: .semibold)
        return button
    }()

    let headerStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .center
        return stackView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        
        addSubview(headerStackView)
        addSubview(dismissButton)
        headerStackView.addArrangedSubview(nameLabel)
        headerStackView.addArrangedSubview(descriptionLabel)
        
        subviews.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        
        NSLayoutConstraint.activate([
            
            headerStackView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 32),
            headerStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            headerStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32),
            
            dismissButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -16),
            dismissButton.centerXAnchor.constraint(equalTo: safeAreaLayoutGuide.centerXAnchor, constant: 16),
            dismissButton.heightAnchor.constraint(equalToConstant: 44),
            dismissButton.widthAnchor.constraint(equalToConstant: 120)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

