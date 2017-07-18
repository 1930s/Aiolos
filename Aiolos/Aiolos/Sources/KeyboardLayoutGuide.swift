//
//  KeyboardLayoutGuide.swift
//  Aiolos
//
//  Created by Matthias Tretter on 14/07/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

import Foundation

/// Used to create a layout guide that pins to the top of the keyboard
final class KeyboardLayoutGuide {

    private let notificationCenter: NotificationCenter
    private let bottomConstraint: NSLayoutConstraint

    // MARK: - Properties

    let topGuide: UILayoutGuide

    // MARK: - Lifecycle

    init(parentView: UIView, notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
        self.topGuide = UILayoutGuide()
        self.topGuide.identifier = "Keyboard Layout Guide"
        parentView.addLayoutGuide(self.topGuide)

        self.bottomConstraint = parentView.bottomAnchor.constraint(equalTo: self.topGuide.bottomAnchor)
        NSLayoutConstraint.activate([
            self.topGuide.heightAnchor.constraint(equalToConstant: 1.0),
            parentView.leadingAnchor.constraint(equalTo: self.topGuide.leadingAnchor),
            parentView.trailingAnchor.constraint(equalTo: self.topGuide.trailingAnchor),
            self.bottomConstraint])

        notificationCenter.addObserver(self, selector: #selector(keyboardWillChangeFrame), name: .UIKeyboardWillChangeFrame, object: nil)
        notificationCenter.addObserver(self, selector: #selector(keyboardWillHide), name: .UIKeyboardWillHide, object: nil)
    }

    deinit {
        self.notificationCenter.removeObserver(self)
    }
}

// MARK: - Private

private extension KeyboardLayoutGuide {

    @objc
    func keyboardWillChangeFrame(_ notification: Notification) {
        guard let owningView = self.topGuide.owningView else { return }
        guard let window = owningView.window else { return }
        guard let keyboardInfo = KeyboardInfo(userInfo: notification.userInfo) else { return }

        // convert own frame to window coordinates, frame is in superview's coordinates
        let owningViewFrame = window.convert(owningView.frame, from: owningView.superview)
        // calculate the area of own frame that is covered by keyboard
        var coveredFrame = owningViewFrame.intersection(keyboardInfo.endFrame)
        // now this might be rotated, so convert it back
        coveredFrame = window.convert(coveredFrame, to: owningView.superview)

        keyboardInfo.animateAlongsideKeyboard {
            self.bottomConstraint.constant = coveredFrame.height
            owningView.layoutIfNeeded()
        }
    }

    @objc
    func keyboardWillHide(_ notification: Notification) {
        self.bottomConstraint.constant = 0.0
        self.topGuide.owningView?.layoutIfNeeded()
    }
}

private struct KeyboardInfo {

    let endFrame: CGRect
    let animationOptions: UIViewAnimationOptions
    let animationDuration: TimeInterval

    init?(userInfo: [AnyHashable: Any]?) {
        guard let userInfo = userInfo else { return nil }
        guard let endFrame = userInfo[UIKeyboardFrameEndUserInfoKey] as? CGRect else { return nil }

        self.endFrame = endFrame

        // UIViewAnimationOption is shifted by 16 bit from UIViewAnimationCurve, which we get here:
        // http://stackoverflow.com/questions/18870447/how-to-use-the-default-ios7-uianimation-curve
        if let animationCurve = userInfo[UIKeyboardAnimationCurveUserInfoKey] as? UInt {
            self.animationOptions = UIViewAnimationOptions(rawValue: animationCurve << 16)
        } else {
            self.animationOptions = .curveEaseInOut
        }

        if let animationDuration = userInfo[UIKeyboardAnimationDurationUserInfoKey] as? Double {
            self.animationDuration = animationDuration
        } else {
            self.animationDuration = 0.25
        }
    }

    func animateAlongsideKeyboard(_ animations: @escaping () -> Void) {
        UIView.animate(withDuration: self.animationDuration, delay: 0.0, options: self.animationOptions, animations: animations)
    }
}