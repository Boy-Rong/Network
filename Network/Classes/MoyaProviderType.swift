//
//  Moya+Extension.swift
//  Alamofire
//
//  Created by 荣恒 on 2019/5/26.
//

import Foundation
import Moya
import Cache


public typealias CompletionClosure = (Swift.Result<(Response,Bool),NetworkError>) -> Void

extension MoyaProviderType {
    /// Moya请求Response方法。加入自己的实现。默认实现，什么也不做。相当于在协议中加入方法
    func requestResponse(_ target : Target, completion: @escaping CompletionClosure) -> Cancellable? {
        #if DEBUG
        fatalError("Network. 此方法没有走自己的实现")
        #endif
        return nil
    }
}

extension MoyaProvider {
    
    /// Moya请求Response方法
    /// - Parameter token: 带有缓存机制，取决于 TargetType.cache，取缓存时用Cache取 NetworkCacheType.cacheRequestKey 字段下的数据，结果为 [String]，再将结果转换为[TargetType]，然后从新发请求
    func requestResponse(_ target: Target, completion: @escaping CompletionClosure) -> Cancellable? {
        /// 请求错误的处理
        let errorClosure = {
            // 缓存失败任务（不是使用数据库）
            if target.cache == .cacheRequest,
                let jsonTarget = target as? TargetTransform,
                let json = try? jsonTarget.toJSON() {
                // 先查所有缓存
                Cache.shared.object([String].self, for: NetworkCacheType.cacheRequestKey, completion: { result in
                    guard var values = try? result.get() else { return }
                    values.append(json)
                    
                    // 再将新的数据加到values中，在异步缓存
                    Cache.shared.asyncCachedObject(values, for: NetworkCacheType.cacheRequestKey, completion: { _ in})
                })
            }
        }
        
        /// 先取缓存
        if target.cache == .cacheResponse,
            let response = try? Cache.shared.response(for: target) {
            completion(.success((response,false)))
        }
        
        /// 如果 没有可用网络 并且 不缓存策略 的情况下 直接发送错误并结束，不发会送请求
        if !ReachabilityService.shared.isHasNetwork && target.cache != .cacheResponse {
            completion(.failure(.error(value: "网络不可用！")))
            errorClosure()
            
            return nil
        }
        
        /// 开始网络请求
        return request(target, completion: { result in
            switch result {
            case let .success(response):
                completion(.success((response,true)))
                if target.cache == .cacheResponse {
                    try? Cache.shared.cachedResponse(response, for: target)
                }
                
            case let .failure(error):
                completion(.failure(.network(value: error)))
                if target.cache == .cacheRequest {
                    errorClosure()
                }
            }
        })
    }
    
}
