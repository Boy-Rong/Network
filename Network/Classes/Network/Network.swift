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
            .do(onNext: { isLoading.onNext(true) })
            .flatMapLatest(request)
            .do(onNext: { isLoading.onNext(false) })
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
            .do(onNext: { isLoading.onNext(true) })
            .withLatestFrom(params)
            .flatMapLatest(request)
            .do(onNext: { isLoading.onNext(false) })
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
///   - params: 生成参数序列，闭包参数为分页数
///   - selector: 请求方法，不需要传page
///
/// - Returns: values 最终结果，直接用就行 loadState 加载状态，result 组合后的数据， total：数据总数, disposable 内部绑定生命周期，可与外部调用者绑定
public func pageNetwork<S,N,P,O,L,T>(frist : S, next : N, params : P, request : @escaping (P.E,Int) throws -> O)
    -> (
    values : Observable<[T]>,
    loadState : Observable<PageLoadState>,
    error : Observable<NetworkError>,
    total : Observable<Int>
    )
    where S : ObservableType, N : ObservableType, P : ObservableConvertibleType, O : ObservableType, O.E == NetworkResult<L>, L : PageList, L.E == T {
        var page = 1
        let loadState = PublishSubject<PageLoadState>()
        let error = PublishSubject<NetworkError>()
        let isNotLoading = loadState.map { !$0.isLoading }
        
        let fristResult = frist
            .pausable(isNotLoading)  // 加载中不能请求
            .do(onNext: { loadState.onNext(.refreshing) })
            .withLatestFrom(params, resultSelector: { ($1, 1) })
            .flatMapLatest(request)
            .do(onNext: { loadState.onNext(.none) })
            .mapSuccess { error.onNext($0) }
            .do(onNext: { page = 1 })
            .shareOnce()
        
        let nextResult = next
            .skipUntil(frist)  // 第一页没请求时不能请求
            .pausable(isNotLoading)  // 加载中不能请求
            .do(onNext: { loadState.onNext(.loadMoreing) })
            .withLatestFrom(params, resultSelector: { ($1, page + 1) })
            .flatMapLatest(request)
            .do(onNext: { loadState.onNext(.none) })
            .mapSuccess { error.onNext($0) }
            .do(onNext: { page += 1 })
            .shareOnce()
        
        let fristValues = fristResult.map({ $0.items }).distinctUntilChanged()

        let nextValues = nextResult.map({ $0.items }).distinctUntilChanged()
            .scan([], accumulator: { $0 + $1 }) // 将加载更多的数据全部加起来
            .withLatestFrom(fristValues, resultSelector: { $1 + $0 })   // 将第一次的结果放在最前面
        
        let values = Observable.merge(fristValues, nextValues)
        
        let total = Observable.merge(
            fristResult.map({ $0.total }),
            nextResult.map({ $0.total })
        )
        
        return (
            values.asObservable(),
            loadState.asObservable(),
            error.asObservable(),
            total.asObservable()
        )
}

/// 分页网络请求通用方法, 忽略重复的结果
///
/// - Parameters:
///   - frist: 上拉序列
///   - next: 下拉序列
///   - params: 生成参数序列，闭包参数为分页数
///   - selector: 请求方法，不需要传page
///
/// - Returns: values 最终结果，直接用就行 loadState 加载状态，result 组合后的数据， total：数据总数, disposable 内部绑定生命周期，可与外部调用者绑定
public func pageNetwork<S,N,P,O,L,T,R>(frist : S, next : N, params : P, request : @escaping (P.E,Int) throws -> O, transform : @escaping (T) -> R)
    ->
    (
    values : Observable<[R]>,
    loadState : Observable<PageLoadState>,
    error : Observable<NetworkError>,
    total : Observable<Int>
    )
    where S : ObservableType, N : ObservableType, P : ObservableConvertibleType, O : ObservableType, O.E == NetworkResult<L>, L : PageList, L.E == T {
        var page = 1
        let loadState = PublishSubject<PageLoadState>()
        let error = PublishSubject<NetworkError>()
        let isNotLoading = loadState.map { !$0.isLoading }
        
        let fristResult = frist
            .pausable(isNotLoading)  // 加载中不能请求
            .do(onNext: { loadState.onNext(.refreshing) })
            .withLatestFrom(params, resultSelector: { ($1, 1) })
            .flatMapLatest(request)
            .do(onNext: { loadState.onNext(.none) })
            .mapSuccess { error.onNext($0) }
            .do(onNext: { page = 1 })
            .shareOnce()
        
        let nextResult = next
            .skipUntil(frist)  // 第一页没请求时不能请求
            .pausable(isNotLoading)  // 加载中不能请求
            .do(onNext: { loadState.onNext(.loadMoreing) })
            .withLatestFrom(params, resultSelector: { ($1, page + 1) })
            .flatMapLatest(request)
            .do(onNext: { loadState.onNext(.none) })
            .mapSuccess { error.onNext($0) }
            .do(onNext: { page += 1 })
            .shareOnce()
        
        let fristValues = fristResult.map({ $0.items }).distinctUntilChanged()
            .observeOn(transformScheduler)
            .mapMany(transform)
        
        let nextValues = nextResult.map({ $0.items }).distinctUntilChanged()
            .observeOn(transformScheduler)
            .mapMany(transform)
            .scan([], accumulator: { $0 + $1 }) // 将加载更多的数据全部加起来
            .withLatestFrom(fristValues, resultSelector: { $1 + $0 })   // 将第一次的结果放在最前面
        
        let values = Observable.merge(
            fristValues,
            nextValues
        )
        
        let total = Observable.merge(
            fristResult.map({ $0.total }),
            nextResult.map({ $0.total })
        )
        
        return (
            values.asObservable(),
            loadState.asObservable(),
            error.asObservable(),
            total.asObservable()
        )
}

/// 并发队列，用来处理异步任务的调度器
private let transformScheduler = ConcurrentDispatchQueueScheduler(qos: .default)
