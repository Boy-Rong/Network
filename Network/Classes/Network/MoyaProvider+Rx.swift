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
    /// Moya请求Response方法
    /// - Parameter token: 带有缓存机制，取决于 TargetType.cache，取缓存时用Cache取 NetworkCacheType.cacheRequestKey 字段下的数据，结果为 [String]，再将结果转换为[TargetType]，然后从新发请求
    func requestResponse(_ token: Base.Target) -> Observable<Response> {
        
        /// 请求错误的处理
        let errorHandle = {
            // 缓存失败任务（如数据库，不是使用缓存）
            if token.cache == .cacheRequest,
                let target = token as? TargetTransform,
                let value = try? target.toJSON() {
                
                // 先异步获取缓存
                Cache.shared.object([String].self, for: NetworkCacheType.cacheRequestKey, completion: { result in
                    guard var values = try? result.get() else { return }
                    values.append(value)
                    
                    // 再将新的数据加到values中，在异步缓存
                    Cache.shared.asyncCachedObject(values, for: NetworkCacheType.cacheRequestKey, completion: { _ in})
                })
            }
        }
        
        return Observable.create({ [weak base] observer in
            
            // 先取缓存
            if token.cache == .cacheResponse,
                let response = try? Cache.shared.response(for: token) {
                observer.onNext(response)
            }
            
            // 如果 没有可用网络 并且 不缓存策略 的情况下 直接发送错误并结束，不发会送请求
            if !ReachabilityService.shared.isHasNetwork && token.cache != .cacheResponse {
                observer.onError(NetworkError.error(value: "网络不可用"))
                errorHandle()
                
                return Disposables.create()
            }
            
            // 发请求
            let cancellableToken = base?.request(token, callbackQueue: nil, progress: nil) { result in
                switch result {
                case let .success(response):
                    observer.onNext(response)
                    observer.onCompleted()
                    
                    // 缓存数据
                    if token.cache == .cacheResponse {
                        Cache.shared.asyncCachedResponse(for: token, completion: { _ in })
                    }
                    
                case let .failure(error):
                    observer.onError(error)
                    errorHandle()
                }
            }
            
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

    /// Designated request-making method.
    ///
    /// - Parameters:
    ///   - token: Entity, which provides specifications necessary for a `MoyaProvider`.
    ///   - callbackQueue: Callback queue. If nil - queue from provider initializer will be used.
    /// - Returns: Single response object.
    func request(_ token: Base.Target, callbackQueue: DispatchQueue? = nil) -> Single<Response> {
        return Single.create { [weak base] single in
            let cancellableToken = base?.request(token, callbackQueue: callbackQueue, progress: nil) { result in
                switch result {
                case let .success(response):
                    single(.success(response))
                case let .failure(error):
                    single(.error(error))
                }
            }

            return Disposables.create {
                cancellableToken?.cancel()
            }
        }
    }

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

