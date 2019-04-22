//
//  Network.swift
//  JYFW
//
//  Created by 荣恒 on 2019/3/18.
//  Copyright © 2019 荣恒. All rights reserved.
//

import Foundation 
import RxSwift

/// 通用网络请求方法
public func network<S,O,T>(start : S, request : @escaping (S.E) throws -> O)
    -> (result : Observable<T>,
        isLoading : Observable<Bool>,
        error : Observable<NetworkError>)
    where S : ObservableType, O : ObservableType, O.E == Result<T,NetworkError> {
        
        let isLoading = PublishSubject<Bool>()
        let error = PublishSubject<NetworkError>()
        let result = start
            .do(onNext: { _ in isLoading.onNext(true) })
            .flatMapLatest(request)
            .do(onNext: { _ in isLoading.onNext(false) })
            .mapSuccess { error.onNext(transformError(form: $0)) }
            .shareOnce()
        
        return (result,isLoading.asObservable(), error.asObservable())
}

/// 通用网络请求方法
///
/// - Parameters:
///   - start: 请求信号
///   - params: 参数
///   - selector: 请求方法
///   - error: 处理错误
/// - Returns: 返回活动加载 isLoading，结果 result
public func network<S,P,O,T>(start : S, params : P, request : @escaping (P.E) throws -> O)
    -> (result : Observable<T>,
        isLoading : Observable<Bool>,
        error : Observable<NetworkError>)
    where S : ObservableType,
    O : ObservableType, O.E == Result<T,NetworkError>, P : ObservableConvertibleType {
        
        let isLoading = PublishSubject<Bool>()
        let error = PublishSubject<NetworkError>()
        let result = start
            .do(onNext: { _ in isLoading.onNext(true) })
            .withLatestFrom(params)
            .flatMapLatest(request)
            .do(onNext: { _ in isLoading.onNext(false) })
            .mapSuccess { error.onNext(transformError(form: $0)) }
            .shareOnce()
        
        return (result,
                isLoading.asObservable(),
                error.asObservable())
}


/// 分页网络请求通用方法
///
/// - Parameters:
///   - frist: 上拉信号
///   - next: 下拉序列
///   - params: 参数，不包含page
///   - selector: 请求方法，需要传page
///
/// - Returns: loadState 加载状态，result 组合后的数据， isMore：是否还有数据, disposables 内部绑定生命周期，可与外部调用者绑定
public func pageNetwork<S,N,P,O,L,T>(
    frist : S, next : N, params : P,
    request : @escaping (P.E, Int) throws -> O)
    -> (values : Observable<[T]>,
        loadState : Observable<PageLoadState>,
        error : Observable<NetworkError>,
        isMore : Observable<Bool>,
        disposables : [Disposable])
where S : ObservableType, N : ObservableType, P : ObservableConvertibleType,
    O : ObservableType, O.E == Result<L,NetworkError>, L : PageList, L.E == T {
        
        var page = 1
        let loadState = PublishSubject<PageLoadState>()
        let error = PublishSubject<NetworkError>()
        let total = PublishSubject<Int>()
        /// 默认没有加载更多
        let isHasMore = BehaviorSubject<Bool>(value: false)
        let values = PublishSubject<[T]>()
        
        let fristResult = frist.do(onNext: { _ in loadState.onNext(.startRefresh) })
            .withLatestFrom(params).map { ($0, 1) }
            .flatMapLatest(request)
            .mapSuccess { error.onNext(transformError(form: $0)) }
            .do(onNext: { _ in
                page += 1
                loadState.onNext(.endRefresh)
            })
            .shareOnce()
        
        let nextResult = next.pausable(isHasMore)
            .do(onNext: { _ in loadState.onNext(.startLoadMore) })
            .withLatestFrom(params).map { ($0, page + 1) }
            .flatMapLatest(request)
            .mapSuccess { error.onNext(transformError(form: $0)) }
            .do(onNext: { _ in
                page += 1
                loadState.onNext(.endLoadMore)
            })
            .shareOnce()
        
         let disposable1 = Observable.combineLatest(
            total.asObservable(),
            values.map({ $0.count }).asObservable())
            .map { $0 - $1 > 0 }
            .subscribe(onNext: { isHasMore.onNext($0) })
        
        let disposable2 = Observable.merge(fristResult.map({ $0.total }),
                                           nextResult.map({ $0.total }))
            .subscribe(onNext: { total.onNext($0) })
        
        let disposable3 = Observable.merge(
            fristResult.map({ $0.items }),
            nextResult.map({ $0.items }).withLatestFrom(values){ $1 + $0 })
            .subscribe(onNext: { values.onNext($0) })
        
        return (values.asObservable(),
                loadState.asObservable(),
                error.asObservable(),
                isHasMore.asObservable(),
                [disposable1,disposable2,disposable3])
}


fileprivate func transformError(form error : Error) -> NetworkError {
    return (error as? NetworkError) ?? .error(value: "转换 NetworkError 失败")
}
