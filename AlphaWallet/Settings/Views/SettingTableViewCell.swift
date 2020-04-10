//
//  SettingTableViewCell.swift
//  AlphaWallet
//
//  Created by Nimit Parekh on 06/04/20.
//

import UIKit

protocol SettingTableViewCellDelegate: class {
    func onOffPassCode(cell: SettingTableViewCell, switchState isOnOff: Bool)
}

class SettingTableViewCell: UITableViewCell {

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    weak var delegate: SettingTableViewCellDelegate?
    fileprivate var titleTopConstraint: NSLayoutConstraint?

    var settings: SettingModel? {
        didSet {
            guard let settingItem = settings else { return }
            if let title = settingItem.title {
                settingTitle.text = title
            }
            if let subtitle = settingItem.subTitle {
                settingSubTitle.text = subtitle
                let subTitleLength = subtitle.count
                if subTitleLength > 0 {
                    titleTopConstraint = settingTitle.centerYAnchor.constraint(equalTo: self.containerView.centerYAnchor, constant: -10)
                    titleTopConstraint?.isActive = true
                }
            }
            if let icon = settingItem.icon {
                settingIconImage.image = icon
            }
        }
    }
    let containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = true // this will make sure its children do not go out of the boundary
        return view
    }()
    
    let settingIconImage: UIImageView = {
        let img = UIImageView()
        img.contentMode = .scaleAspectFill // image will never be strecthed vertially or horizontally
        img.translatesAutoresizingMaskIntoConstraints = false // enable autolayout
        img.clipsToBounds = true
        return img
    }()
    
     let settingTitle: UILabel = {
           let label = UILabel()
            label.font = R.font.sourceSansProRegular(size: 17)
           label.textColor = R.color.black()
           label.translatesAutoresizingMaskIntoConstraints = false
           return label
       }()
       
       let settingSubTitle: UILabel = {
           let label = UILabel()
           label.font = R.font.sourceSansProRegular(size: 12)
           label.textColor =  R.color.dove()
           label.clipsToBounds = true
           label.translatesAutoresizingMaskIntoConstraints = false
           return label
       }()
    
    let tableSwitch: UISwitch = {
        let switchBtn = UISwitch()
        switchBtn.isHidden = true
        switchBtn.translatesAutoresizingMaskIntoConstraints = false
        return switchBtn
    }()
    
    @objc func switchChanged(_ sender: Any) {
        // switch was tapped (toggled on/off)
        if let v = sender as? UISwitch {
            delegate?.onOffPassCode(cell: self, switchState: v.isOn)
        }
    }
    
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
      
        containerView.addSubview(settingIconImage)
        containerView.addSubview(settingTitle)
        containerView.addSubview(settingSubTitle)
        containerView.addSubview(tableSwitch)
//    containerView.backgroundColor = UIColor.red
        self.contentView.addSubview(containerView)

        containerView.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor).isActive = true
        containerView.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor).isActive = true
        containerView.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor).isActive = true
        containerView.heightAnchor.constraint(equalToConstant: 60).isActive = true

        settingIconImage.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor).isActive = true
        settingIconImage.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor, constant: 16).isActive = true
        settingIconImage.widthAnchor.constraint(equalToConstant: 40).isActive = true
        settingIconImage.heightAnchor.constraint(equalToConstant: 40).isActive = true

        settingTitle.leadingAnchor.constraint(equalTo: self.settingIconImage.trailingAnchor, constant: 20).isActive = true
        settingTitle.trailingAnchor.constraint(equalTo: self.containerView.trailingAnchor).isActive = true

        titleTopConstraint = settingTitle.centerYAnchor.constraint(equalTo: self.containerView.centerYAnchor)
        titleTopConstraint?.isActive = true

        settingSubTitle.topAnchor.constraint(equalTo: self.settingTitle.bottomAnchor).isActive = true
        settingSubTitle.leadingAnchor.constraint(equalTo: self.settingIconImage.trailingAnchor, constant: 20).isActive = true

        tableSwitch.centerYAnchor.constraint(equalTo: self.containerView.centerYAnchor).isActive = true
        tableSwitch.leadingAnchor.constraint(equalTo: self.settingTitle.trailingAnchor, constant: -68).isActive = true
        tableSwitch.addTarget(self, action: #selector(switchChanged(_:)), for: .valueChanged)
  }
  
  required init?(coder aDecoder: NSCoder) {
      super.init(coder: aDecoder)
  }
}
