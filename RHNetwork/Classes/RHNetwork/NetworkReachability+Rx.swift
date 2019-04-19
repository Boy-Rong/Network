//
//  NetworkReachability+Rx.swift
//  RHSwiftExtensions
//
//  Created by 荣恒 on 2019/4/19.
//

import RxSwift
import RxCocoa

extension NetworkReachabilityService : ReactiveCompatible {}

public extension Reactive where Base == NetworkReachabilityService {
    
    /// 网路状态序列
    var status : Observable<NetworkReachabilityStatus> {
        return NotificationCenter.default.rx.notification(.reachabilityChanged)
            .flatMap({ notification -> Observable<NetworkReachabilityStatus> in
                if let status = notification.userInfo?[NetworkKey.reachabilityChanged] as? NetworkReachabilityStatus {
                    return Observable.just(status)
                } else {
                    return Observable.empty()
                }
            }).distinctUntilChanged()
    }
    
    /// 是否有网
    var isHasNetwork : Observable<Bool> {
        return status.map({ value in
            let values : [NetworkReachabilityStatus] = [.notReachable,.unknown]
            return !values.contains(value)
        })
    } 
    
}
