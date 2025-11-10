//
//  CommandStatusViewController.swift
//  TSDemo
//
//  指令发送状态弹窗 - Command Status Alert
//

import UIKit

/// 指令发送状态视图控制器
final class CommandStatusViewController: UIViewController {
    
    enum State {
        case sending(String)
        case success(String)
        case failure(String)
    }
    
    private var state: State
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 16
        view.layer.masksToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let indicator = UIActivityIndicatorView(style: .large)
    private let statusImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.isHidden = true
        imageView.tintColor = .systemGreen
        return imageView
    }()
    
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .label
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Initialization
    init(state: State) {
        self.state = state
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        apply(state: state, animated: false)
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        view.addSubview(containerView)
        containerView.addSubview(stackView)
        
        stackView.addArrangedSubview(indicator)
        stackView.addArrangedSubview(statusImageView)
        stackView.addArrangedSubview(messageLabel)
        
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(lessThanOrEqualToConstant: 260),
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24),
            indicator.heightAnchor.constraint(equalToConstant: 44),
            indicator.widthAnchor.constraint(equalTo: indicator.heightAnchor),
            statusImageView.heightAnchor.constraint(equalToConstant: 44),
            statusImageView.widthAnchor.constraint(equalTo: statusImageView.heightAnchor)
        ])
    }
    
    // MARK: - Public
    func update(state: State) {
        apply(state: state, animated: true)
    }
    
    func dismiss(after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.dismiss(animated: true)
        }
    }
    
    // MARK: - Private
    private func apply(state: State, animated: Bool) {
        self.state = state
        let changes = {
            switch state {
            case .sending(let message):
                self.indicator.isHidden = false
                self.indicator.startAnimating()
                self.statusImageView.isHidden = true
                self.messageLabel.textColor = .label
                self.messageLabel.text = message
            case .success(let message):
                self.indicator.stopAnimating()
                self.indicator.isHidden = true
                self.statusImageView.tintColor = .systemGreen
                self.statusImageView.image = UIImage(systemName: "checkmark.circle.fill")
                self.statusImageView.isHidden = false
                self.messageLabel.textColor = .label
                self.messageLabel.text = message
            case .failure(let message):
                self.indicator.stopAnimating()
                self.indicator.isHidden = true
                self.statusImageView.tintColor = .systemRed
                self.statusImageView.image = UIImage(systemName: "xmark.circle.fill")
                self.statusImageView.isHidden = false
                self.messageLabel.textColor = .systemRed
                self.messageLabel.text = message
            }
        }
        if animated {
            UIView.transition(with: containerView, duration: 0.25, options: .transitionCrossDissolve, animations: changes)
        } else {
            changes()
        }
    }
}
