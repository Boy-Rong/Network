//
//  ResponsePlugin.swift
//  Network.swift
//
//  Created by ash on 2019/10/16.
//

import Foundation

struct ResponsePlugin: PluginType {
    /// Called to modify a result before completion.
    func process(_ result: Result<Moya.Response, MoyaError>, target: TargetType) -> Result<Moya.Response, MoyaError> {
        
        switch result {
        case .success(let value):
            do {
                let anyData = try value.mapJSON()
                
                guard let jsonDictionary = anyData as? NSDictionary else {
                    let errorStr = "无效的json格式"
                    return .failure(MoyaError.requestMapping(errorStr))
                }
                let codeKey = NetworkConfigure.code
                let successCode = NetworkConfigure.success
                let messageKey = NetworkConfigure.message
                guard let code = jsonDictionary.value(forKeyPath: codeKey) as? Int else {
                    let error = "服务器code解析错误\n\(cc_responseDescribe(value) ?? "")"
                    return .failure(MoyaError.requestMapping(error))
                }
                guard code == successCode else {
                    cc_handleServiceCode(code)
                    let message = (jsonDictionary.value(forKeyPath: messageKey) as? String) ?? "code不等于\(successCode)"
                    let error = NetworkError.service(code: code, message: message)
                    return .failure(MoyaError.parameterEncoding(error))
                }
                return .success(value)
            } catch {
                let error = MoyaError.jsonMapping(value)
                return .failure(error)
            }
        case .failure(let error):
            return .failure(error)
        }
    }
}

/// 处理服务器Code
private func cc_handleServiceCode(_ code: Int) {
    switch code {
    case 401:
        NotificationCenter.default.post(name: .networkService_401, object: nil)
        
    case 402 ..< 500:
        NotificationCenter.default.post(name: .networkService_4XX, object: nil, userInfo: ["code" : code])
        
    default: break
    }
}

/// 描述响应，正式环境不打印
private func cc_responseDescribe(_ response: Response) -> String? {
    #if DEBUG
    return String(data: response.data, encoding: .utf8) ?? "无response.data"
    #else
    return nil
    #endif
}
