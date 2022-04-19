import UIKit

final class ResponderView: UIView {
    
    let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.register(ActiveSessionCell.self, forCellReuseIdentifier: "sessionCell")
        return tableView
    }()
    
    let scanButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Scan QR code", for: .normal)
        button.setImage(UIImage(systemName: "qrcode.viewfinder"), for: .normal)
        button.backgroundColor = .systemBlue
        button.tintColor = .white
        button.layer.cornerRadius = 8
        return button
    }()
    
    let pasteButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Paste URI", for: .normal)
        button.setImage(UIImage(systemName: "doc.on.clipboard"), for: .normal)
        button.backgroundColor = .systemBlue
        button.tintColor = .white
        button.layer.cornerRadius = 8
        return button
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        
        addSubview(tableView)
        addSubview(pasteButton)
        addSubview(scanButton)
        
        subviews.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: scanButton.topAnchor),
            
            pasteButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -16),
            pasteButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            pasteButton.heightAnchor.constraint(equalToConstant: 44),
            
            scanButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -16),
            scanButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            scanButton.heightAnchor.constraint(equalToConstant: 44),
            
            pasteButton.widthAnchor.constraint(equalTo: scanButton.widthAnchor),
            scanButton.leadingAnchor.constraint(equalTo: pasteButton.trailingAnchor, constant: 16)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
