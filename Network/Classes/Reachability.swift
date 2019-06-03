//
//  Network+Reachability.swift
//  Alamofire
//
//  Created by 荣恒 on 2019/4/19.
//

import Foundation
import Alamofire
import RxSwift


/// 网路可用性服务
public struct ReachabilityService {
    
    public enum Key : String {
        case statusChanged = "status.changed"
    }
    
    public static let shared = ReachabilityService()
    
    private let reachability = NetworkReachabilityManager()
    
    /// 当前网路状态
    var currentStatus : ReachabilityStatus {
        return reachability?.networkReachabilityStatus ?? .notReachable
    }
    
    /// 是否有网
    var isHasNetwork : Bool {
        return reachability?.isReachable ?? false
    }
    
    private let currentSubject = BehaviorSubject<ReachabilityStatus>(value: .notReachable)
    
    /// 当前网络状态序列
    var current : Observable<ReachabilityStatus> {
        return currentSubject.asObservable()
    }
    
    /// 默认开启监听网络状况
    private init() {
        reachability?.listener = networkStatusChange(_:)
        reachability?.startListening()
    }
    
    private func networkStatusChange(_ status : ReachabilityStatus) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .reachabilityChanged, object: nil,
                                            userInfo: [Key.statusChanged : status])
        }
        currentSubject.onNext(status)
    }
    
    /// 停止监听网路状态
    func stop() {
        reachability?.stopListening()
    }
    
    
}



