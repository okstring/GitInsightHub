//
//  OAuthViewModel.swift
//  GithubInsight
//
//  Created by Issac on 2021/10/18.
//

import Foundation
import RxSwift
import RxCocoa
import RxSwiftExt
import AuthenticationServices

private let loginURL = URL(string: "https://github.com/login/oauth/authorize?client_id=\(Keys.github.appID)&scope=\(Configs.App.githubScope)")!
private let callbackURLScheme = "gitinsighthub"

class OAuthViewModel: ViewModel, ViewModelType {
    let disposeBag = DisposeBag()
    
    struct Input {
        let oAuthLoginTrigger: Driver<Void>
    }
    
    struct Output {
        
    }
    
    private var session: ASWebAuthenticationSession?
    
    let code = PublishSubject<String>()
    let tokenSaved = PublishSubject<Void>()
    
    func transform(input: Input) -> Output {
        let usecase = usecase
        let sceneCoordinator = sceneCoordinator
        
        input.oAuthLoginTrigger.drive(onNext: { [weak self] in
            
            self?.session = ASWebAuthenticationSession(url: loginURL, callbackURLScheme: callbackURLScheme, completionHandler: { callbackURL, error in
                
                if let error = error {
                    print(error)
                }
                if let code = callbackURL?.queryParameters?["code"] {
                    self?.code.onNext(code)
                }
            })
            if #available(iOS 13.0, *) {
                self?.session?.presentationContextProvider = self
            }
            self?.session?.start()
        }).disposed(by: disposeBag)
        
        let tokenRequest = code.flatMapLatest { (code) -> Observable<RxSwift.Event<Token>> in
            let clientId = Keys.github.appID
            let clientSecret = Keys.github.apiKey
            
            return usecase.createAccessToken(clientId: clientId,
                                                  clientSecret: clientSecret,
                                                  code: code,
                                                  redirectURI: nil)
                .asObservable()
                .materialize()
        }.share()
        
        tokenRequest.elements().subscribe(onNext: { [weak self] (token) in
            AuthManager.setToken(token)
            self?.tokenSaved.onNext(())
        }).disposed(by: disposeBag)
        
        
        tokenSaved.subscribe(onNext: {
            let tabsViewModel = TabsViewModel(authorized: AuthManager.shared.hasValidToken, usecase: usecase, sceneCoordinator: sceneCoordinator)
            sceneCoordinator.transition(to: .tabs(tabsViewModel), using: .root, animated: true)
        }).disposed(by: rx.disposeBag)
        
        return Output()
    }
}

extension OAuthViewModel: ASWebAuthenticationPresentationContextProviding {
    @available(iOS 13.0, *)
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let window = UIApplication.shared.windows.first(where: \.isKeyWindow)
        return window ?? ASPresentationAnchor()
    }
}
