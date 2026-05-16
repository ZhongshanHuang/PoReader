//
//  CustomTailTruncationTokenViewController.swift
//  PoLabelDemo
//
//  Created by HzS on 2024/9/19.
//

import UIKit
import PoText

class CustomTailTruncationTokenViewController: ExampleBaseViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        setupExamples()
    }

    private func setupExamples() {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 18
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            stackView.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24)
        ])

        let font = UIFont.systemFont(ofSize: 20)
        let examples: [(title: String, mode: NSLineBreakMode, token: NSAttributedString?)] = [
            ("Default .byTruncatingHead", .byTruncatingHead, nil),
            ("Default .byTruncatingTail", .byTruncatingTail, nil),
            ("Default .byTruncatingMiddle", .byTruncatingMiddle, nil),
            ("Custom tail truncation token", .byTruncatingTail, customTailTruncationToken(font: font))
        ]

        for example in examples {
            stackView.addArrangedSubview(makeSection(title: example.title,
                                                     lineBreakMode: example.mode,
                                                     font: font,
                                                     tailTruncationToken: example.token))
        }
    }

    private func makeSection(title: String,
                             lineBreakMode: NSLineBreakMode,
                             font: UIFont,
                             tailTruncationToken: NSAttributedString?) -> UIView {
        let section = UIStackView()
        section.axis = .vertical
        section.spacing = 8

        let titleLabel = UILabel()
        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        if #available(iOS 13.0, *) {
            titleLabel.textColor = .secondaryLabel
        } else {
            titleLabel.textColor = .darkGray
        }
        titleLabel.text = title

        let label = PoLabel()
        label.numberOfLines = 1
        label.textVerticalAlignment = .center
        label.lineBreakMode = lineBreakMode
        label.attributedText = exampleText(font: font)
        label.tailTruncationToken = tailTruncationToken
        label.layer.borderWidth = 0.5
        label.layer.borderColor = UIColor(red: 0, green: 0.436, blue: 1, alpha: 1).cgColor
        label.layer.cornerRadius = 6
        label.translatesAutoresizingMaskIntoConstraints = false
        label.heightAnchor.constraint(equalToConstant: 46).isActive = true

        section.addArrangedSubview(titleLabel)
        section.addArrangedSubview(label)
        return section
    }

    private func exampleText(font: UIFont) -> NSAttributedString {
        NSAttributedString(
            string: "START0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZEND",
            attributes: [.font: font]
        )
    }

    private func customTailTruncationToken(font: UIFont) -> NSAttributedString {
        var tokenAttributesContainer = PoAttributeContainer()
        tokenAttributesContainer.font = font
        var highlight = TextHighlight()
        highlight.foregroundColor = UIColor(red: 0.578, green: 0.79, blue: 1, alpha: 1)
        highlight.tapAction = { (_, _, _) in
            print("tap more")
        }
        tokenAttributesContainer.textHighlight = highlight

        let tokenText = NSMutableAttributedString(attributeContainer: tokenAttributesContainer) {
            String(unicodeScalarLiteral: "\u{2026}").po.asAttributedString()
                .foregroundColor(.black)
            "more".po.asAttributedString()
                .foregroundColor(UIColor(red: 0, green: 0.449, blue: 1, alpha: 1))
        }

        let seeMore = PoLabel()
        seeMore.attributedText = tokenText
        seeMore.sizeToFit()
        return NSMutableAttributedString.po.attachmentString(with: .view(seeMore),
                                                             size: seeMore.size,
                                                             alignToFont: font,
                                                             verticalAlignment: .center)
    }
}
