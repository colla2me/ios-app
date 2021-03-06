import UIKit

class ChangeNumberVerificationCodeViewController: ChangeNumberViewController {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var verificationCodeField: VerificationCodeField!
    @IBOutlet weak var invalidCodeLabel: UILabel!
    var resendButton: CountDownButton!
    
    private let resendInterval = 60
    
    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = Localized.NAVIGATION_TITLE_ENTER_VERIFICATION_CODE(mobileNumber: context.newNumberRepresentation)
        resendButton = bottomWrapperView.leftButton
        resendButton.addTarget(self, action: #selector(resendAction(_:)), for: .touchUpInside)
        resendButton.normalTitle = Localized.BUTTON_TITLE_RESEND_CODE
        resendButton.pendingTitleTemplate = Localized.BUTTON_TITLE_RESEND_CODE_PENDING
        resendButton.titleLabel?.font = UIFont.systemFont(ofSize: 15)
        resendButton.beginCountDown(resendInterval)
        verificationCodeField.becomeFirstResponder()
        bottomWrapperBottomConstraint.update(offset: -(ChangeNumberViewController.lastKeyboardFrame.height + BottomWrapperView.defaultLayoutInset.bottom))
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        resendButton.restartTimerIfNeeded()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        resendButton.releaseTimer()
    }
    
    override func continueAction(_ sender: Any) {
        checkVerificationCodeAction(sender)
    }

    @IBAction func checkVerificationCodeAction(_ sender: Any) {
        invalidCodeLabel.isHidden = true
        let continueButton = bottomWrapperView.continueButton
        let code = verificationCodeField.text
        let context = self.context
        if code.count != verificationCodeField.numberOfDigits {
            continueButton?.isEnabled = false
        } else {
            continueButton?.isEnabled = true
            continueButton?.isBusy = true
            let request = AccountRequest.createAccountRequest(verificationCode: code, registrationId: nil, pin: context.pin, sessionSecret: nil)
            AccountAPI.shared.changePhoneNumber(verificationId: context.verificationId, accountRequest: request, completion: { [weak self] (result) in
                guard let weakSelf = self else {
                    return
                }
                switch result {
                case .success:
                    if let old = AccountAPI.shared.account {
                        let new = Account(withAccount: old, phone: context.newNumber)
                        AccountAPI.shared.account = new
                    }
                    weakSelf.verificationCodeField.resignFirstResponder()
                    weakSelf.alert(nil, message: Localized.PROFILE_CHANGE_NUMBER_SUCCEEDED, handler: { (_) in
                        weakSelf.navigationController?.dismiss(animated: true, completion: nil)
                    })
                case .failure(let error, let didHandled):
                    weakSelf.bottomWrapperView.continueButton.isBusy = false
                    weakSelf.verificationCodeField.clear()
                    if !didHandled {
                        if error.kind == .invalidVerificationCode {
                            weakSelf.invalidCodeLabel.isHidden = false
                        } else {
                            weakSelf.alert(error.kind.localizedDescription ?? error.description)
                        }
                    }
                }
            })
        }
    }

    @objc func resendAction(_ sender: Any) {
        resendButton.isBusy = true
        AccountAPI.shared.sendCode(to: context.newNumber, purpose: .phone) { [weak self] (result) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.resendButton.isBusy = false
            switch result {
            case .success(let verification):
                weakSelf.resendButton.beginCountDown(weakSelf.resendInterval)
                weakSelf.context.verificationId = verification.id
            case .failure(let error, let didHandled):
                if !didHandled {
                    weakSelf.alert(error.kind.localizedDescription ?? error.description)
                }
            }
        }
    }
    
    class func instance(context: ChangeNumberContext) -> ChangeNumberVerificationCodeViewController {
        let vc = Storyboard.contact.instantiateViewController(withIdentifier: "verification_code") as! ChangeNumberVerificationCodeViewController
        vc.context = context
        return vc
    }

}
