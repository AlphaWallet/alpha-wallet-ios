import UIKit

final class SessionDetailsView: UIView {
    
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

    let headerStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .center
        return stackView
    }()
    
  
    let pingButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Ping", for: .normal)
        button.backgroundColor = .systemBlue
        button.tintColor = .white
        button.layer.cornerRadius = 8
        return button
    }()
    
    let tableView = UITableView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        
        addSubview(iconView)
        addSubview(headerStackView)
        addSubview(tableView)

        headerStackView.addArrangedSubview(nameLabel)
        headerStackView.addArrangedSubview(urlLabel)
        headerStackView.addArrangedSubview(descriptionLabel)
        addSubview(pingButton)
        
        subviews.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        
        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 64),
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 64),
            iconView.heightAnchor.constraint(equalToConstant: 64),
            
            headerStackView.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 32),
            headerStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            headerStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32),
            
            tableView.topAnchor.constraint(equalTo: headerStackView.bottomAnchor, constant: 0),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 0),
            tableView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),

            pingButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -16),
            pingButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            pingButton.heightAnchor.constraint(equalToConstant: 44),
            pingButton.widthAnchor.constraint(equalToConstant: 64),
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
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

