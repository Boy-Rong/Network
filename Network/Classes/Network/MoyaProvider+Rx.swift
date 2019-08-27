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

extension MoyaProvider: ReactiveCompatible {}

/// JSON解析器
private let decoder = JSONDecoder()

// MARK: - 自己封装
public extension Reactive where Base: MoyaProviderType {
    
    /// 请求数据，带缓存逻辑
    func request(_ token : Base.Target) -> Observable<Response> {
        let network = requestNetwork(token).map { Optional($0) }.startWith(nil)
        let cache = requestCache(token).map { Optional($0) }.startWith(nil)
        
        return Observable.combineLatest(cache,network)
            .flatMap { responses -> Observable<Response> in
                switch responses {
                case (let .some(cacheResponse),nil): return .just(cacheResponse)
                case (_, let .some(networkResponse)): return .just(networkResponse)
                default: return .empty()
                }
        }
    }
    
    /// 请求成功
    func request(_ token : Base.Target,
                 codeKey : String = NetworkConfigure.code,
                 messageKey : String = NetworkConfigure.message,
                 successCode : Int = NetworkConfigure.success
        ) -> Observable<Void> {
        
        return request(token).flatMap({ response -> Observable<Void> in

            guard let jsonDictionary = (try? response.mapJSON()) as? NSDictionary else {
                let error = "无效的json格式"
                return .error(NetworkError.error(value: error))
            }
            guard let code = jsonDictionary.value(forKeyPath: codeKey) as? Int else {
                let error = "服务器code解析错误\n\(responseDescribe(response) ?? "")"
                return .error(NetworkError.error(value: error))
            }
            guard code == successCode else {
                handleServiceCode(code)
                let message = (jsonDictionary.value(forKeyPath: messageKey) as? String) ?? "code不等于\(successCode)"
                return .error(NetworkError.service(code: code, message: message))
            }
            
            return .just(())
        })
    }
    
    /// 请求成功的结果数据
    func request<T>(_ token : Base.Target,
                    dataKey : String = NetworkConfigure.data,
                    codeKey : String = NetworkConfigure.code,
                    messageKey : String = NetworkConfigure.message,
                    successCode : Int = NetworkConfigure.success
        ) -> Observable<T> where T : Codable {

        return request(token).flatMap({ response -> Observable<T> in
            
            guard let jsonDictionary = (try? response.mapJSON()) as? NSDictionary else {
                let error = "无效的json格式"
                return .error(NetworkError.error(value: error))
            }
            guard let code = jsonDictionary.value(forKeyPath: codeKey) as? Int else {
                let error = "服务器code解析错误\n\(responseDescribe(response) ?? "")"
                return .error(NetworkError.error(value: error))
            }
            guard code == successCode else {
                handleServiceCode(code)
                let message = (jsonDictionary.value(forKeyPath: messageKey) as? String) ?? "code不等于\(successCode)"
                return .error(NetworkError.service(code: code, message: message))
            }
            guard
                let jsonObject = jsonDictionary.value(forKeyPath: dataKey),
                JSONSerialization.isValidJSONObject(jsonObject),
                let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject),
                jsonData.count > 1 else {
                return .error(NetworkError.emptyData)
            }
            
            do {
                let object = try decoder.decode(T.self, from: jsonData)
                return .just(object)
            } catch let error {
                return .error(NetworkError.error(value: "请求成功，但data解析错误\nerror: \(error)"))
            }
        })
    }
}

/// 处理服务器Code
private func handleServiceCode(_ code: Int) {
    switch code {
    case 401:
        NotificationCenter.default.post(name: .networkService_401, object: nil)
        
    case 402 ..< 500:
        NotificationCenter.default.post(name: .networkService_4XX, object: nil, userInfo: ["code" : code])
        
    default: break
    }
}

/// 描述响应，正式环境不打印
private func responseDescribe(_ response: Response) -> String? {
    #if DEBUG
    return String(data: response.data, encoding: .utf8) ?? "无response.data"
    #else
    return nil
    #endif
}

extension Reactive where Base: MoyaProviderType {
    
    func requestNetwork(_ token : Base.Target) -> Observable<Response> {
        /// 先判断是否有网
        guard ReachabilityService.shared.isHasNetwork else { return .error(NetworkError.error(value: "没有网络可用")) }
        
        /// 开始网络请求
        return requestResponse(token)
            .do(onNext: { response in
                /// 成功请求后缓存数据
                if let token = token as? CacheType, token.cache == .cacheResponse {
                    token.cache(response: response)
                }
            }, onError: { error in
                /// 失败后缓存请求
                if let token = token as? CacheType, token.cache == .cacheRequest {
                    token.cacheRequest()
                }
            })
    }
    
    /// 请求缓存，若不是缓存或者没有缓存，直接返回完成事件
    func requestCache(_ token : Base.Target) -> Observable<Response> {
        guard let token = token as? CacheType,
            token.cache == .cacheResponse else {
                return .empty()
        }
        
        return Observable<Response>.create { observer in
            token.getResponse({ result in
                switch result {
                case .success(let response):
                    observer.onNext(response)
                    
                case .failure: break
                }
                observer.onCompleted()
            })
            
            return Disposables.create()
        }
    }
    
}


// MARK: - Moya/RxSwift
public extension Reactive where Base: MoyaProviderType {
    
    /// 请求网络数据基本方法，不加任何逻辑
    func requestResponse(_ token: Base.Target, callbackQueue: DispatchQueue? = nil) -> Observable<Response> {
        return Observable.create({ [weak base] observer in
            let cancellableToken = base?.request(token, callbackQueue: callbackQueue, progress: nil) { result in
                switch result {
                case let .success(response):
                    observer.onNext(response)
                    observer.onCompleted()
                case let .failure(error):
                    observer.onError(error)
                }
            }
            
            return Disposables.create {
                cancellableToken?.cancel()
            }
        })
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

