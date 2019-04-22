//
//  RxSwift+Extensions.swift
//  Alamofire
//
//  Created by 荣恒 on 2019/4/21.
//

import RxSwift

extension ObservableType {
    func shareOnce() -> Observable<E> {
        return share(replay: 1)
    }
}

extension ObservableType {
    
    /// 根据P 决定是否暂停发送值（实质是过滤P为fasle的值）
    func pausable<P: ObservableType> (_ pauser: P) -> Observable<E> where P.E == Bool {
        return withLatestFrom(pauser) { element, paused in
            (element, paused)
            }
            .filter { _, paused in paused }
            .map { element, _ in element }
    }
    
}


extension ObservableType {
    
    /// map 成功后的值（过滤失败），并处理 Failure事件
    func mapSuccess<T>(failure : ((Error) -> Void)? = nil) -> Observable<T> where Self.E == Swift.Result<T,NetworkError> {
        return `do`(onNext: { result in
            switch result {
            case .success: break
            case let .failure(error): failure?(error)
            }
        })
            .map({ try $0.get() })
    }
    
}
