//
//  Types.swift
//
//  Created by 荣恒 on 2019/4/19.
//

import Foundation
import Alamofire

@_exported import Moya
@_exported import RxSwift

// MARK: - 类型定义
/// Moya
//public typealias TargetType = Moya.TargetType
//public typealias Response = Moya.Response
//public typealias Task = Moya.Task
//public typealias HttpMethod = Moya.Method
//public typealias MoyaProvider = Moya.MoyaProvider
//public typealias MultipartFormData = Moya.MultipartFormData
//public typealias PluginType = Moya.PluginType
//
//public typealias ParameterEncoding = Alamofire.ParameterEncoding
//public typealias JSONEncoding = Alamofire.JSONEncoding
//public typealias URLEncoding = Alamofire.URLEncoding
//public typealias PropertyListEncoding = Alamofire.PropertyListEncoding

/// 网路结果类型
public typealias NetworkResult<T> = Swift.Result<T,NetworkError>
/// 网路结果序列
public typealias NetworkObservable<T> = Observable<NetworkResult<T>>



public typealias ReachabilityStatus = Alamofire.NetworkReachabilityManager.NetworkReachabilityStatus

/// 网络请求Key值, 外部可根据实际需求更改值
public struct NetworkResultKey {
    public private(set) static var code = "code"
    public private(set) static var message = "msg"
    public private(set) static var data = "data"
    public private(set) static var success = 200
    
    /// 替换默认的网络请求Key
    public static func replace(
        codeKey : String = NetworkResultKey.code,
        messageKey : String = NetworkResultKey.message,
        dataKey : String = NetworkResultKey.data,
        successKey : Int = NetworkResultKey.success) {
        self.code = codeKey
        self.message = messageKey
        self.data = dataKey
        self.success = successKey
    }
}

public extension Notification.Name {
    
    /// 服务器401通知
    static let networkService_401 = Notification.Name("network_service_401")
    
    /// 网路可达性改变通知
    static let reachabilityChanged = Notification.Name("reachabilityChanged")
    
}


/// 分页返回结果类型
public protocol PageList : Codable & Equatable {
    associatedtype E : Codable & Equatable
    var items : [E] { get }
    var total : Int { get }
}

/// 分页加载状态
public enum PageLoadState : String {
    /// 开始刷新
    case startRefresh
    /// 结束刷新
    case endRefresh
    /// 开始上拉加载
    case startLoadMore
    /// 结束上拉加载
    case endLoadMore
    
    public var isLoading : Bool {
        switch self {
        case .startRefresh, .startLoadMore:
            return true
        case .endRefresh, .endLoadMore:
            return false
        }
    }
}

/// 通用网络错误
public enum NetworkError : Error {
    /// 网络错误
    case network(value : Error)
    /// 服务器错误
    case service(code : Int, message : String)
    /// 返回字段不是code,msg,data 格式
    case error(value : String)
}

/// 缓存类型
public enum NetworkCacheType : Int {
    /// 不缓存
    case none
    /// 缓存成功结果
    case cacheResponse
    /// 缓存失败任务
    case cacheRequest
    
    /// 缓存错误请求的Key
    static var cacheRequestKey : String {
        return "Cache.error.cacheRequest"
    }
}

