//
//  LoginView.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 10/12/24.
//

import UIKit
import AuthenticationServices
import GoogleSignIn
import FirebaseAuth
import FirebaseCore

protocol LoginViewControllerDelegate: AnyObject {
    func loginViewController(_ viewController: LoginViewController, didTapSignUpButton: Bool)
}

class LoginViewController: UIViewController {
    
    let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Login"
        label.font = .systemFont(ofSize: UIFont.preferredFont(forTextStyle: .largeTitle).pointSize, weight: .bold)
        return label
    }()
    
    let emailTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Email"
        textField.borderStyle = .roundedRect
        return textField
    }()
    
    let passwordTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Password"
        textField.borderStyle = .roundedRect
        return textField
    }()
    
    let loginButton: UIButton = {
        let button = UIButton()
        button.layer.cornerRadius = 8
        var config = UIButton.Configuration.borderedProminent()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: UIFont.buttonFontSize, weight: .medium)
        ]
        
        config.attributedTitle = AttributedString("Login", attributes: AttributeContainer(attributes))
        button.configuration = config
        return button
    }()
    
    let container: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    let divider = DividerView()
    
    let signUpLabel: UILabel = {
        let label = UILabel()
        label.text = "Don't have an account yet?"
        return label
    }()
    
    let signUpButton: UIButton = {
        let button = UIButton()
        button.setTitle("Sign up", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: UIFont.labelFontSize, weight: .semibold)
        button.setTitleColor(.link, for: .normal)
        return button
    }()
    
    
    let signUpContainer: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    weak var delegate: LoginViewControllerDelegate?
    var service: FirebaseService!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        signUpButton.addAction(didTapSignUpButton(), for: .touchUpInside)
        
        let appleLoginButton = ASAuthorizationAppleIDButton(type: .signIn, style: traitCollection.userInterfaceStyle == .light ? .black : .white)
        appleLoginButton.addAction(didTapAppleLoginButton(), for: .touchUpInside)
        appleLoginButton.cornerRadius = 8
        
        let googleLoginButton = UIButton()
        googleLoginButton.addAction(didTapGoogleLoginButton(), for: .touchUpInside)
        googleLoginButton.layer.cornerRadius = 8
        googleLoginButton.layer.borderWidth = 1
        googleLoginButton.layer.borderColor = UIColor.black.cgColor
        
        var config = UIButton.Configuration.borderedProminent()
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: UIFont.buttonFontSize, weight: .medium)
        ]
        
        config.attributedTitle = AttributedString("Sign in with Google", attributes: AttributeContainer(attributes))
        
        // Resize custom images suck
        if let originalImage = UIImage(named: "google") {
            let targetSize = CGSize(width: 30, height: 30)
            
            UIGraphicsBeginImageContextWithOptions(targetSize, false, 0.0)
            originalImage.draw(in: CGRect(origin: .zero, size: targetSize))
            let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            config.image = resizedImage
        }
        
        config.imagePadding = 8
        config.imagePlacement = .leading
        config.baseBackgroundColor = traitCollection.userInterfaceStyle == .light ? .white : .black
        config.baseForegroundColor = traitCollection.userInterfaceStyle == .light ? .black : .white

        googleLoginButton.configuration = config
        
        container.addArrangedSubview(titleLabel)
        container.addArrangedSubview(emailTextField)
        container.addArrangedSubview(passwordTextField)
        container.addArrangedSubview(loginButton)
        container.addArrangedSubview(divider)
        container.addArrangedSubview(googleLoginButton)
        container.addArrangedSubview(appleLoginButton)
        container.addArrangedSubview(UIView())
        container.setCustomSpacing(32, after: titleLabel)
        
        signUpContainer.addArrangedSubview(signUpLabel)
        signUpContainer.addArrangedSubview(signUpButton)
        
        view.addSubview(container)
        view.addSubview(signUpContainer)
        
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: view.topAnchor),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            loginButton.heightAnchor.constraint(equalToConstant: 50),
            googleLoginButton.heightAnchor.constraint(equalToConstant: 50),
            appleLoginButton.heightAnchor.constraint(equalToConstant: 50),
            
            signUpContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            signUpContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    func didTapSignUpButton() -> UIAction {
        return UIAction { [weak self] _ in
            guard let self else { return }
            delegate?.loginViewController(self, didTapSignUpButton: true)
        }
    }
    
    func didTapGoogleLoginButton() -> UIAction {
        return UIAction { _ in
            Task {
                do {
                    let res = try await self.service.signInWithGoogle(self)
                } catch {
                    print("Error sign in with google: \(error)")
                }
            }
        }
    }
    
    func didTapAppleLoginButton() -> UIAction {
        return UIAction { _ in
            self.service.signInWithApple(self)
        }
    }
}

extension LoginViewController: ASAuthorizationControllerDelegate {
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let appleIDToken = appleIDCredential.identityToken else {
                print("Unable to fetch identity token")
                return
            }
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                print("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
                return
            }

            let credential = OAuthProvider.appleCredential(withIDToken: idTokenString,
                                                           rawNonce: nil,
                                                           fullName: appleIDCredential.fullName)
            
            Task {
                if let guestUser = service.auth.currentUser, guestUser.isAnonymous {
                    do {
                        try await guestUser.link(with: credential)
                        print("Successfully linked guest account to Apple account!")
                        service.authState = .permanent
                        NotificationCenter.default.post(name: .userStateChangedNotification, object: nil)
                    } catch let error as NSError {
                        if error.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
                            print("This Apple account is already linked to another account.")
                        }
                        
                        // Fallback to sign in directly
                        do {
                            let res = try await service.auth.signIn(with: credential)
                            
//                            // Get new user's information
//                            if let existingUser = try await service.getUser(uid: res.user.uid) {
//                                print("Got existing user!")
//                                service.name = existingUser.name
//                                service.uid = res.user.uid
//                                service.pfpImage = try? await service.getProfilePicture(uid: res.user.uid) ?? nil
//                            }
                            
                            print("Signed in to Apple account!")
                            service.authState = .permanent
                            NotificationCenter.default.post(name: .userStateChangedNotification, object: nil)
                        } catch {
                            print("Error signing into Apple account: \(error.localizedDescription)")
                        }
                    }
                    NotificationCenter.default.post(name: .userStateChangedNotification, object: nil)
                }
            }
            
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        // Handle error.
        print("Sign in with Apple errored: \(error)")
    }
}

extension LoginViewController: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return self.view.window!
    }
}


#Preview {
    LoginViewController()
}
//
//extension UIViewController {
//    var lineView: UIView {
//        let view = UIView()
//        view.backgroundColor = .separator
//        view.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true
//        return view
//    }
//}
