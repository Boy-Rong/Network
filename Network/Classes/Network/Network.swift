//
//  Network.swift
//  JYFW
//
//  Created by 荣恒 on 2019/3/18.
//  Copyright © 2019 荣恒. All rights reserved.
//

import Foundation 
import RxSwift
import RxSwiftExtensions


public func network<RequestParams,Result>(
    start: Observable<RequestParams>,
    request: @escaping (RequestParams) -> Observable<Result>)
    -> (result: Observable<Result>,
    isLoading: Observable<Bool>,
    error: Observable<NetworkError>) {
        let isActivity = ActivityIndicator()
        let error = ErrorTracker()
        
        let result = start.flatMapLatest({ params in
            request(params)
                .trackActivity(isActivity)
                .trackError(error)
                .catchErrorJustComplete()
        })
            .shareOnce()
        
        return (
            result,
            isActivity.asObservable(),
            error.asObservable().map({ $0 as? NetworkError }).filterNil()
        )
}

public func network<Start: ObservableType,RequestParams,Result>(
    start: Start,
    params: Observable<RequestParams>,
    request: @escaping (RequestParams) -> Observable<Result>)
    -> (result: Observable<Result>,
    isLoading: Observable<Bool>,
    error: Observable<NetworkError>) {
        let isActivity = ActivityIndicator()
        let error = ErrorTracker()
        
        let result = start.withLatestFrom(params)
            .flatMapLatest({ params in
                request(params)
                    .trackActivity(isActivity)
                    .trackError(error)
                    .catchErrorJustComplete()
            })
            .shareOnce()
        
        return (
            result,
            isActivity.asObservable(),
            error.asObservable().map({ $0 as? NetworkError }).filterNil()
        )
}

public func page<RequestParams, Next: ObservableType,  List: PageList & Equatable>(
    requestFirstPageWith requestFirstPage: Observable<RequestParams>,
    requestNextPageWhen requestNextPage: Next,
    requestFromParams: @escaping (RequestParams,Int) -> Observable<List>)
    ->
    (values: Observable<[List.Value]>,
    total: Observable<Int>,
    isLoading: Observable<Bool>,
    error: Observable<NetworkError>) {
        let isActivity = ActivityIndicator()
        let error = ErrorTracker()
        let requestSuccess = BehaviorSubject<Void>(value: ())
        let total = BehaviorSubject<Int>(value: 0)
        
        /// 当前分页
        let requestPage = requestFirstPage.mapVoid().startWithEmpty()
            .flatMapLatest {
                requestSuccess.mapValue(1).scan(0) { $0 + $1 }
        }
        
        /// requestFirstPage 每次来时重新开始请求序列
        /// 切记 requestPage 在 requestFirstPage来之后才会订阅
        let values = requestFirstPage.flatMapLatest { params in
            requestNextPage
                .pausable(total.map({ $0 > 0 }))    // 没有数据时不能下一页
                .withLatestFrom(requestPage)
                .startWith(1)   /// 请求第一页
                .flatMapLatest({ page -> Observable<[List.Value]> in
                    return requestFromParams(params, page)
                        .do(onNext: { total.onNext($0.total) })
                        .map({ $0.items })
                        .distinctUntilChanged()
                        .doNext { requestSuccess.onNext(()) }
                        .trackActivity(isActivity)
                        .trackError(error)
                        .catchErrorJustComplete()
                })
                .takeWhile({ !$0.isEmpty }) /// 没有数据时停止
                .scan([], accumulator: { $0 + $1 }) /// 结果每次累加
            }
            .shareOnce()
        
        return (
            values,
            total.asObservable(),
            isActivity.asObservable(),
            error.asObservable().map({ $0 as? NetworkError }).filterNil()
        )
}


/// 分页请求通用处理
///
/// - Parameters:
///   - requestFirstPage: 第一页请求，需要带参数
///   - requestNextPage: 第二页请求不需要带参数
///   - requestFromParams: 请求方法
///   - transformListValue: 将结结果转换成需要的值，在异步中执行
public func page<RequestParams, Next: ObservableType,  List: PageList & Equatable, Value>(
    requestFirstPageWith requestFirstPage: Observable<RequestParams>,
    requestNextPageWhen requestNextPage: Next,
    requestFromParams: @escaping (RequestParams,Int) -> Observable<List>,
    transformListValue: @escaping (List.Value) -> (Value))
    ->
    (values: Observable<[Value]>,
    total: Observable<Int>,
    loadState: Observable<PageLoadState>,
    error: Observable<NetworkError>) {
        let isActivity = ActivityIndicator()
        let error = ErrorTracker()
        let requestSuccess = BehaviorSubject<Void>(value: ())
        let total = BehaviorSubject<Int>(value: 0)
        
        let isRefresh = Observable.merge(
            requestFirstPage.mapValue(true),
            requestNextPage.mapValue(false)
        )
        
        let loadState = isActivity.asObservable()
            .withLatestFromAndSelf(isRefresh)
            .map(loadState(form:and:))
        
        /// 当前分页
        let requestPage = requestFirstPage.mapVoid().startWithEmpty()
            .flatMapLatest {
                requestSuccess.mapValue(1).scan(0) { $0 + $1 }
        }
        
        /// requestFirstPage 每次来时重新开始请求序列
        /// 切记 requestPage 在 requestFirstPage来之后才会订阅
        let values = requestFirstPage.flatMapLatest { params in
            requestNextPage
                .pausable(total.map({ $0 > 0 }))    // 没有数据时不能下一页
                .withLatestFrom(requestPage)
                .startWith(1)   /// 请求第一页
                .flatMapLatest({ page -> Observable<[Value]> in
                    return requestFromParams(params, page)
                        .do(onNext: { total.onNext($0.total) })
                        .map({ $0.items })
                        .distinctUntilChanged()
                        .observeOn(transformScheduler)
                        .mapMany(transformListValue)
                        .doNext { requestSuccess.onNext(()) }
                        .trackActivity(isActivity)
                        .trackError(error)
                        .catchErrorJustComplete()
                })
                .takeWhile({ !$0.isEmpty }) /// 没有数据时停止
                .scan([], accumulator: { $0 + $1 }) /// 结果每次累加
            }
            .shareOnce()
        
        return (
            values,
            total.asObservable(),
            loadState,
            error.asObservable().map({ $0 as? NetworkError }).filterNil()
        )
}

private func loadState(form isActivity: Bool, and isRefresh: Bool) -> PageLoadState {
    switch (isActivity, isRefresh) {
    case (true,true): return .refreshing
    case (true,false): return .loadMoreing
    case (false,_): return .none
    }
}

/// 并发调度队列
private let transformScheduler = ConcurrentDispatchQueueScheduler(qos: .default)
