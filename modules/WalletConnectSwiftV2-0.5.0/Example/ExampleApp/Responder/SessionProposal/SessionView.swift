import UIKit

final class SessionView: UIView {
    
    let iconView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .systemFill
        imageView.layer.cornerRadius = 32
        return imageView
    }()
    
    let nameLabel: UILabel = {
        let label = UILabel()
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
    
    let urlLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 14.0)
        label.textColor = .tertiaryLabel
        return label
    }()
    
    let approveButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Approve", for: .normal)
        button.backgroundColor = .systemBlue
        button.tintColor = .white
        button.layer.cornerRadius = 8
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17.0, weight: .semibold)
        return button
    }()
    
    let rejectButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Reject", for: .normal)
        button.backgroundColor = .systemRed
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
    
    let chainsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 10
        stackView.alignment = .leading
        return stackView
    }()
    
    let methodsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 10
        stackView.alignment = .leading
        return stackView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        
        addSubview(iconView)
        addSubview(headerStackView)
        addSubview(chainsStackView)
        addSubview(methodsStackView)
        addSubview(approveButton)
        addSubview(rejectButton)
        headerStackView.addArrangedSubview(nameLabel)
        headerStackView.addArrangedSubview(urlLabel)
        headerStackView.addArrangedSubview(descriptionLabel)
        
        subviews.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        
        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 64),
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 64),
            iconView.heightAnchor.constraint(equalToConstant: 64),
            
            headerStackView.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 32),
            headerStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            headerStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32),
            
            chainsStackView.topAnchor.constraint(equalTo: headerStackView.bottomAnchor, constant: 24),
            chainsStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            chainsStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32),
            
            methodsStackView.topAnchor.constraint(equalTo: chainsStackView.bottomAnchor, constant: 24),
            methodsStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            methodsStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32),
            
            approveButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -16),
            approveButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            approveButton.heightAnchor.constraint(equalToConstant: 44),
            
            rejectButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -16),
            rejectButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            rejectButton.heightAnchor.constraint(equalToConstant: 44),
            
            approveButton.widthAnchor.constraint(equalTo: rejectButton.widthAnchor),
            rejectButton.leadingAnchor.constraint(equalTo: approveButton.trailingAnchor, constant: 16),
        ])
    }
    
    func loadImage(at url: String) {
        guard let iconURL = URL(string: url) else { return }
        DispatchQueue.global().async {
            if let imageData = try? Data(contentsOf: iconURL) {
                DispatchQueue.main.async { [weak self] in
                    self?.iconView.image = UIImage(data: imageData)
                }
            }
        }
    }
    
    func list(chains: [String]) {
        let label = UILabel()
        label.text = "Chains"
        label.font = UIFont.systemFont(ofSize: 17.0, weight: .heavy)
        chainsStackView.addArrangedSubview(label)
        chains.forEach {
            chainsStackView.addArrangedSubview(ListItem(text: $0))
        }
    }
    
    func list(methods: [String]) {
        let label = UILabel()
        label.text = "Methods"
        label.font = UIFont.systemFont(ofSize: 17.0, weight: .heavy)
        methodsStackView.addArrangedSubview(label)
        methods.forEach {
            methodsStackView.addArrangedSubview(ListItem(text: $0))
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class ListItem: UIView {
    
    private let label: UILabel = {
        let label = UILabel()
        label.textColor = .secondaryLabel
        return label
    }()
    
    init(text: String) {
        super.init(frame: .zero)
        label.text = text
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            label.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
