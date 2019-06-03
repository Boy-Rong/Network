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
    
    /// 请求参数，从Task解析的，存在一定问题
    var parameter : [String : Any]? {
        switch self.task {
        case let .requestParameters(value):
            return value.parameters
            
        default:
            return nil
        }
    }

}

/// Target转换协议
public protocol TargetTransform {
    
    /// TargetType转换到String
    func toJSON() throws -> String
    
    /// 根据String生成TargetType
    init(json : String) throws
}
extension TargetTransform where Self : TargetType {
    func toJSON() throws -> String {
        guard let parameter = parameter else { throw NetworkError.error(value: "没有参数") }
        guard JSONSerialization.isValidJSONObject(parameter) else { throw NetworkError.error(value: "参数格式不是JSON") }
        let jsonData = try JSONSerialization.data(withJSONObject: parameter, options: [])
        
        guard let json = String(data: jsonData, encoding: .utf8) else { throw NetworkError.error(value: "数据解析失败") }
        return json
    }
}


