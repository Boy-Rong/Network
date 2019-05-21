//
//  TargetType+Extensions.swift
//  RHNetwork
//
//  Created by 荣恒 on 2019/4/19.
//

import Foundation
import Moya


// MARK: - 扩展 TargetType 加入缓存属性
public extension TargetType {
    
    /// 缓存类型，默认没有缓存
    var cache : NetworkCacheType {
        return .none
    }
    
    /// 缓存Key
    var cachedKey: String {
        return "\(baseURL.absoluteString)\(path),\(method.rawValue),\(headers ?? [:]),\(task)"
    }
    
    var headers: [String : String]? { return nil }
    var sampleData: Data { return Data() }
    
    /// 对应的请求
    var request : URLRequest? {
        return try? MoyaProvider.defaultEndpointMapping(for: self).urlRequest()
    }
    
}

/// Target转换协议
public protocol TargetTransform {
    
    /// TargetType转换到String
    func toJSON() throws -> String
    
    /// 根据String生成TargetType
    init(json : String) throws
    
}


