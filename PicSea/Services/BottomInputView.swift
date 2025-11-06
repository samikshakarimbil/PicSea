//
//  BottomInputView.swift
//  PicSea
//
//


import UIKit

final class BottomInputView: UIView {
    let textField = UITextField()
    let button = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder); setup()
    }

    private func setup() {
        backgroundColor = .secondarySystemBackground

        textField.placeholder = "Album name…"
        textField.borderStyle = .roundedRect
        textField.returnKeyType = .done
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)

        button.setTitle("Submit", for: .normal)

        let stack = UIStackView(arrangedSubviews: [textField, button])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .fill

        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        let g = safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: g.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: g.bottomAnchor, constant: -8),
            textField.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 60)
    }
}
