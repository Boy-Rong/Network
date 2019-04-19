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
public protocol TargetTransform where Self : TargetType {
    
    /// TargetType转换到String
    func toValue() -> String?
    
    /// 根据String生成TargetType
    init(value : String)
    
}


public extension Task {
    /// 自定义Int值
    var rawValue : Int {
        switch self {
        case .requestPlain: return 0
        case .requestData: return 1
        case .requestJSONEncodable: return 2
        case .requestCustomJSONEncodable: return 3
        case .requestParameters: return 4
        case .requestCompositeData: return 5
        case .requestCompositeParameters: return 6
        case .uploadFile: return 7
        case .uploadMultipart: return 8
        case .uploadCompositeMultipart: return 9
        case .downloadDestination: return 10
        case .downloadParameters: return 11
        }
    }
}
