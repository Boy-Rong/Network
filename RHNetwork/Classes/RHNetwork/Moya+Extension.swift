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
import RHCache

// MARK: - Moya RxSwift网络请求方法扩展
public extension Reactive where Base: MoyaProviderType {
    
    /// Moya请求Response方法
    /// - Parameter token: 带有缓存机制，取决于 TargetType.cache，取缓存时用RHCache取 NetworkCacheType.cacheRequestKey 字段下的数据，结果为 [String]，再将结果转换为[TargetType]，然后从新发请求
    func requestResponse<T : TargetType>(_ token: T) -> Observable<Response> {
        
        /// 请求错误的处理
        let errorHandle = {
            // 缓存失败任务（如数据库，不是使用缓存）
            if token.cache == .cacheRequest,
                let target = token as? TargetTransform,
                let value = target.toValue() {
                
                // 先异步获取缓存
                RHCache.shared.object([String].self, for: NetworkCacheType.cacheRequestKey, completion: { result in
                    guard var values = try? result.get() else { return }
                    values.append(value)
                    
                    // 再将新的数据加到values中，在异步缓存
                    RHCache.shared.asyncCachedObject(values, for: NetworkCacheType.cacheRequestKey, completion: { _ in})
                })
            }
        }
        
        return Observable.create({ [weak base] observer in
            
            // 先取缓存
            if token.cache == .cacheResponse,
                let response = try? RHCache.shared.response(for: token) {
                observer.onNext(response)
            }
            
            // 如果 没有可用网络 并且 不缓存策略 的情况下 直接发送错误并结束，不发会送请求
            if !NetworkReachabilityService.shared.isHasNetwork && token.cache != .cacheResponse {
                observer.onError(NetworkError.error(value: "网络不可用"))
                errorHandle()
                
                return Disposables.create()
            }
            
            // 发请求
            let cancellableToken = base?.request(token as! Base.Target, callbackQueue: nil, progress: nil) { result in
                switch result {
                case let .success(response):
                    observer.onNext(response)
                    observer.onCompleted()
                    
                    // 缓存数据
                    if token.cache == .cacheResponse {
                        RHCache.shared.asyncCachedResponse(for: token, completion: { _ in })
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
    func requestResult<T : TargetType, R : Codable>(
        _ token: T,
        dataKey : String = NetworkKey.data,
        codeKey : String = NetworkKey.code,
        messageKey : String = NetworkKey.message,
        successCode : Int = NetworkKey.success) -> NetworkObservable<R> {
        return requestResponse(token)
            .mapResult(dataKey: dataKey, codeKey: codeKey,
                       messageKey: messageKey, successCode: successCode)
    }
    
    /// Moya请求Success方法 -> Observable<Result<Void,NetworkError>>
    func requestSuccess<T : TargetType>(
        _ token: T,
        codeKey : String = NetworkKey.code,
        messageKey : String = NetworkKey.message,
        successCode : Int = NetworkKey.success) -> NetworkObservable<Void> {
        return requestResponse(token)
            .mapSuccess(codeKey: codeKey, messageKey: messageKey, successCode: successCode)
    }
    
}


// MARK: - 对 Response 序列扩展，转成Result<T,Error>
extension ObservableType where E == Response {
    
    /// 将内容 map成 Result<T,NetworkError>
    func mapResult<T : Codable>(dataKey : String, codeKey : String,
                                messageKey : String, successCode : Int)
        -> NetworkObservable<T> {
            return debugNetwork()
                .flatMap({ response -> NetworkObservable<T> in
                guard let code = try? response.map(Int.self, atKeyPath: codeKey),
                    let message = try? response.map(String.self, atKeyPath: messageKey) else {
                        let error = String(data: response.data, encoding: .utf8) ?? "没有错误信息"
                        return .just(.failure(.error(value: error)))
                }
                guard code == successCode else {
                    return .just(.failure(.service(code: code, message: message)))
                }
                guard let data = try? response.map(T.self, atKeyPath: dataKey) else {
                    let error = String(data: response.data, encoding: .utf8) ?? "没有错误信息"
                    return .just(NetworkResult.failure(.error(value: error)))
                }
                
                return .just(.success(data))
            })
                .catchError({ .just(.failure(.network(value: $0))) })
    }
    
    /// 将内容 map成 Result<Void,NetworkError>
    func mapSuccess(codeKey : String, messageKey : String, successCode : Int)
        -> NetworkVoidObservable {
            return debugNetwork()
                .flatMap({ response -> NetworkVoidObservable in
                guard let code = try? response.map(Int.self, atKeyPath: codeKey),
                    let message = try? response.map(String.self, atKeyPath: messageKey) else {
                        let error = String(data: response.data, encoding: .utf8) ?? "没有错误信息"
                        return .just(.failure(.error(value: error)))
                }
                guard code == successCode else {
                    return .just(.failure(.service(code: code, message: message)))
                }
                
                return .just(.success(()))
            })
                .catchError({ .just(.failure(.network(value: $0))) })
    }
    
    /// 预处理网路请求（发出服务器401通知），打印网路请求的响应
    func debugNetwork(codeKey : String = NetworkKey.code,
                      messageKey : String = NetworkKey.message) -> Observable<Response> {
        return self.do(onNext: { response in
            logDebug("================================请求结果==============================")
            if let request = response.request,
                let url = request.url,
                let httpMethod = request.httpMethod  {
                logDebug("URL : \(url)   \(httpMethod)")
                logDebug("请求头：\(request.allHTTPHeaderFields ?? [:])")
            }
            
            if let code = try? response.map(Int.self, atKeyPath: codeKey),
                let message = try? response.map(String.self, atKeyPath: messageKey) {
                logDebug("code :\(code) \t message : \(message) \t HttpCode : \(response.response?.statusCode ?? -1) ")
                logDebug("响应数据：\n \(String(data: response.data, encoding: .utf8) ?? "")")
                
                switch code {
                case 401:   // Token时效，发出退出登录通知
                    NotificationCenter.default.post(name: .networkService_401, object: nil)
                    logDebug("Token失效")
                    
                default: break
                }
                
            } else {
                logDebug("请求错误：\(response)")
                logDebug("请求错误详情：\(String(data: response.data, encoding: .utf8) ?? "没有错误信息")")
            }
            
            logDebug("=====================================================================")
        }, onError: { error in
            logDebug("请求错误：\(error)")
        })
    }
    
}


/// 简单打印，带时间
func logDebug<T>(_ msg : T) {
    #if DEBUG
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "HH:mm:ss"
    let dateString = dateFormatter.string(from: Date())
    
    print("\(dateString) : \(msg)")
    #endif
}
