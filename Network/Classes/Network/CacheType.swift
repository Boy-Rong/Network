//
//  Cache+Moya.swift
//
//  Created by 荣恒 on 2019/3/29.
//  Copyright © 2019 荣恒. All rights reserved.
//

import Moya

public protocol CacheType where Self : TargetType {
    /// 缓存类型，默认没有缓存
    var cache : NetworkCacheType { get }
    /// 缓存Key
    var cachedKey: String { get }
    
    /// 成功请求后缓存数据，根据cachedKey去缓存
    func cache(response : Response)
    /// 异步获取缓存，根据cachedKey去取
    func getResponse(_ complete: @escaping (Swift.Result<Response,Error>) -> Void)
    /// 请求失败后的回调
    func cacheRequest()
}
public extension CacheType {
    
    var cachedKey: String {
        return "\(baseURL.absoluteString)\\\(path)+\(method)+\(task)"
    }
    
    func cacheRequest() { }
    
    /// 对应的请求
    var request : URLRequest? {
        return try? MoyaProvider.defaultEndpointMapping(for: self).urlRequest()
    }
}


// MARK: - 扩展 TargetType 加入缓存属性
public extension TargetType {
    var headers: [String : String]? { return nil }
    var sampleData: Data { return Data() }
}

