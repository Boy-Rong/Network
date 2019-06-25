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
/// - Parameters:
///   - start: 开始请求的序列
///   - request: 请求方法序列
/// - Returns: result 结果，isLoading 是否加载中，error 错误信息
public func network<S,O,T>(start : S,
                           request : @escaping (S.E) throws -> O)
    -> (result : Observable<T>,
        isLoading : Observable<Bool>,
        error : Observable<NetworkError>)
where S : ObservableType,
    O : ObservableType,
    O.E == NetworkResult<T> {
        
        let isLoading = PublishSubject<Bool>()
        let error = PublishSubject<NetworkError>()
        let result = start
            .do(onNext: { _ in isLoading.onNext(true) })
            .flatMapLatest(request)
            .do(onNext: { _ in isLoading.onNext(false) })
            .mapSuccess { error.onNext($0) }
            .shareOnce()
        
        return (result,
                isLoading.asObservable(),
                error.asObservable())
}

/// 通用网络请求方法
///
/// - Parameters:
///   - start: 请求序列
///   - params: 参数序列
///   - request: 请求方法
/// - Returns: result 结果，isLoading 是否加载中，error 错误信息
public func network<S,P,O,T>(start : S,
                             params : P,
                             request : @escaping (P.E) throws -> O)
    -> (result : Observable<T>,
        isLoading : Observable<Bool>,
        error : Observable<NetworkError>)
where S : ObservableType,
    O : ObservableType,
    O.E == NetworkResult<T>,
    P : ObservableConvertibleType {
        
        let isLoading = PublishSubject<Bool>()
        let error = PublishSubject<NetworkError>()
        let result = start
            .do(onNext: { _ in isLoading.onNext(true) })
            .withLatestFrom(params)
            .flatMapLatest(request)
            .do(onNext: { _ in isLoading.onNext(false) })
            .mapSuccess { error.onNext($0) }
            .shareOnce()
        
        return (result,
                isLoading.asObservable(),
                error.asObservable())
}


/// 分页网络请求通用方法, 忽略重复的结果
///
/// - Parameters:
///   - frist: 上拉序列
///   - next: 下拉序列
///   - params: 参数序列，不包含page
///   - selector: 请求方法，需要传page
///
/// - Returns: values 最终结果，直接用就行 loadState 加载状态，result 组合后的数据， isMore：是否还有数据, disposable 内部绑定生命周期，可与外部调用者绑定
public func pageNetwork<S,N,P,O,L,T,R>(
    frist : S, next : N, params : P,
    request : @escaping (P.E, Int) throws -> O,
    transform : @escaping (T) -> R
) ->  (
    values : Observable<[R]>,
    loadState : Observable<PageLoadState>,
    error : Observable<NetworkError>,
    total : Observable<Int>,
    disposable : Disposable
    )
    where S : ObservableType, N : ObservableType, P : ObservableConvertibleType, O : ObservableType, O.E == NetworkResult<L>, L : PageList, L.E == T {
        var page = 1
        let loadState = PublishSubject<PageLoadState>()
        let error = PublishSubject<NetworkError>()
        let total = PublishSubject<Int>()
        /// 默认没有加载更多
        let isHasMore = BehaviorSubject<Bool>(value: false)
        let values = PublishSubject<[R]>()
        
        let fristResult = frist.do(onNext: { loadState.onNext(.startRefresh) })
            .withLatestFrom(params).map { ($0, 1) }
            .flatMapLatest(request)
            .do(onNext: { loadState.onNext(.endRefresh) })
            .mapSuccess { error.onNext($0) }
            .do(onNext: { page = 1 })
            .shareOnce()
        
        let nextResult = next.pausable(isHasMore)
            .do(onNext: { loadState.onNext(.startLoadMore) })
            .withLatestFrom(params).map { ($0, page + 1) }
            .flatMapLatest(request)
            .do(onNext: { loadState.onNext(.endLoadMore) })
            .mapSuccess { error.onNext($0) }
            .do(onNext: { page += 1 })
            .shareOnce()
        
        let fristValues = fristResult.map({ $0.items })
            .distinctUntilChanged().mapMany(transform)
            .subscribeOn(transformScheduler)
        
        let nextValues = nextResult.map({ $0.items })
            .distinctUntilChanged().mapMany(transform)
            .withLatestFrom(values){ $1 + $0 }
            .subscribeOn(transformScheduler)
        
        let disposable1 = Observable.merge(fristValues,nextValues)
            .subscribe(onNext: { values.onNext($0) })
        
         let disposable2 = Observable.combineLatest(
                total.asObservable(),
                values.map({ $0.count }).asObservable()
            )
            .map { $0 - $1 > 0 }
            .subscribe(onNext: { isHasMore.onNext($0) })
        
        let disposable3 = Observable.merge(
                fristResult.map({ $0.total }),
                nextResult.map({ $0.total })
            )
            .subscribe(onNext: { total.onNext($0) })
        
        
        return (values.asObservable(),
                loadState.asObservable(),
                error.asObservable(),
                total.asObservable(),
                CompositeDisposable(disposables: [disposable1,disposable2,disposable3]))
}

/// 并发队列，用来处理异步任务的调度器
private let transformScheduler = ConcurrentDispatchQueueScheduler(qos: .default)
