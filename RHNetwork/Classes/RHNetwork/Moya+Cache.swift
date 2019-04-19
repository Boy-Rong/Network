//
//  Cache+Moya.swift
//  RHSwiftExtensions
//
//  Created by 荣恒 on 2019/3/29.
//  Copyright © 2019 荣恒. All rights reserved.
//

import RHCache
import Moya

/// response存储者
fileprivate var responseStorage : Storage<Response>?

fileprivate func getStorage() throws -> Storage<Response> {
    if let storage = responseStorage {
        return storage
    } else {
        return try Storage<Response>(
            diskConfig: DiskConfig(name: "jiangromm.cache.network.response"),
            memoryConfig: MemoryConfig(),
            transformer: TransformerFactory.forResponse())
    }
}


//MARK : - 缓存网络成功的数据
public extension RHCache {
    
    /// 同步获取成功请求的数据
    func response(for target: TargetType) throws -> Response {
        return try getStorage().object(forKey: target.cachedKey)
    }
    
    /// 异步获取成功请求的数据
    func response(for target: TargetType, completion : @escaping (Result<Response>) -> Void) {
        do {
            try getStorage().async.object(forKey: target.cachedKey, completion: completion)
        } catch let error {
            completion(Result.failure(error))
        }
    }
    
    /// 同步缓存成功请求的数据
    func cachedResponse(_ cachedResponse: Response, for target: TargetType) throws {
        try getStorage().setObject(cachedResponse, forKey: target.cachedKey)
    }
    
    /// 异步缓存成功请求的数据
    func asyncCachedResponse(for target: TargetType, completion : @escaping (Result<Response>) -> Void) {
        do {
            try getStorage().async.object(forKey: target.cachedKey, completion: completion)
        } catch let error {
            completion(Result.failure(error))
        }
    }
    
    /// 删除缓存数据
    func removeCachedResponse(for target: TargetType) throws {
        try getStorage().removeObject(forKey: target.cachedKey)
    }
    
    /// 删除所有缓存数据
    func removeAllCachedResponses() throws {
        try getStorage().removeAll()
    }
    
}


extension TransformerFactory {
    
    static func forResponse() -> Transformer<Response> {
        let toData: (Response) -> Data = { object in
            return object.data
        }
        
        let fromData: (Data) -> Response = { data in
            return Response.init(statusCode: 200, data: data)
        }
        
        return Transformer<Response>(toData: toData, fromData: fromData)
    }
    
}
