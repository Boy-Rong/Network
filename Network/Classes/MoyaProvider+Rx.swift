//
//  Moya+Extension.swift
//  RHMoyaCache
//
//  Created by 荣恒 on 2018/9/28.
//  Copyright © 2018 荣恒. All rights reserved.
//

import Foundation
import RxSwift
import Moya
import Cache

extension MoyaProvider: ReactiveCompatible {}

// MARK: - 自己封装
public extension Reactive where Base: MoyaProviderType {

    func request(_ token: Base.Target) -> Observable<Response> {
        
        return Observable.create({ [weak base] observer in
            let cancellableToken = base?.requestResponse(token, completion: { result in
                switch result {
                case .success(let response, let isOK):
                    observer.onNext(response)
                    if isOK { observer.onCompleted() }
                    
                case let .failure(error):
                    observer.onError(error)
                }
            })
            
            return Disposables.create {
                cancellableToken?.cancel()
            }
        })
    }
    
    /// Moya请求Result方法 -> Observable<Result<R,NetworkError>>
    func requestResult<T : Codable>(
        _ token: Base.Target,
        dataKey : String = NetworkResultKey.data,
        codeKey : String = NetworkResultKey.code,
        messageKey : String = NetworkResultKey.message,
        successCode : Int = NetworkResultKey.success) -> NetworkObservable<T> {
        return request(token)
            .mapResult(dataKey: dataKey,
                       codeKey: codeKey,
                       messageKey: messageKey,
                       successCode: successCode)
    }
    
    /// Moya请求Success方法 -> Observable<Result<Void,NetworkError>>
    func requestSuccess(
        _ token: Base.Target,
        codeKey : String = NetworkResultKey.code,
        messageKey : String = NetworkResultKey.message,
        successCode : Int = NetworkResultKey.success) -> NetworkObservable<Void> {
        return request(token)
            .mapSuccess(codeKey: codeKey,
                        messageKey: messageKey,
                        successCode: successCode)
    }
}


// MARK: - Moya/RxSwift
public extension Reactive where Base: MoyaProviderType {

    /// Designated request-making method with progress.
    func requestWithProgress(_ token: Base.Target, callbackQueue: DispatchQueue? = nil) -> Observable<ProgressResponse> {
        let progressBlock: (AnyObserver) -> (ProgressResponse) -> Void = { observer in
            return { progress in
                observer.onNext(progress)
            }
        }

        let response: Observable<ProgressResponse> = Observable.create { [weak base] observer in
            let cancellableToken = base?.request(token, callbackQueue: callbackQueue, progress: progressBlock(observer)) { result in
                switch result {
                case .success:
                    observer.onCompleted()
                case let .failure(error):
                    observer.onError(error)
                }
            }

            return Disposables.create {
                cancellableToken?.cancel()
            }
        }

        // Accumulate all progress and combine them when the result comes
        return response.scan(ProgressResponse()) { last, progress in
            let progressObject = progress.progressObject ?? last.progressObject
            let response = progress.response ?? last.response
            return ProgressResponse(progress: progressObject, response: response)
        }
    }
}

