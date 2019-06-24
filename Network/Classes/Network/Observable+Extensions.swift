//
//  RxSwift+Extensions.swift
//  Alamofire
//
//  Created by 荣恒 on 2019/4/21.
//

import RxSwift

extension ObservableType {
    func shareOnce() -> Observable<E> {
        return share(replay: 1)
    }
}

extension ObservableType {
    
    /// 根据P 决定是否暂停发送值（实质是过滤P为fasle的值）
    func pausable<P: ObservableType> (_ pauser: P) -> Observable<E> where P.E == Bool {
        return withLatestFrom(pauser) { element, paused in
            (element, paused)
            }
            .filter { _, paused in paused }
            .map { element, _ in element }
    }
    
}

extension ObservableType {
    /// 过滤掉nil
    func filterNil<T>() -> Observable<T> where E == Optional<T> {
        return filter({ $0 != nil }).map({ $0! })
    }
}

extension ObservableType {
    
    /// map 成功后的值（过滤失败），并处理 Failure事件
    func mapSuccess<T>(failure : @escaping (NetworkError) -> Void) -> Observable<T> where Self.E == Swift.Result<T,NetworkError> {
        return `do`(onNext: { result in
            switch result {
            case .success: break
            case let .failure(error): failure(error)
            }
        })
            .map({ try? $0.get() }).filterNil()
    }
    
    func `do`(onNext : @escaping () -> Void) -> Observable<E> {
        return `do`(onNext: { _ in onNext() })
    }
    
}

// MARK: - 序列 Collection Map
public extension ObservableType where E: Collection {
    
    /// 将序列中的数组map
    func mapMany<T>(_ transform: @escaping (Self.E.Element) -> T) -> Observable<[T]> {
        return self.map { collection -> [T] in
            collection.map(transform)
        }
    }
    
}

extension ObservableType {
    /// 更具策略 flatMap
    func flatMap<O>(strategy : RequestStrategy, for selector : @escaping (Self.E) throws -> O) -> Observable<O.E>
        where O : ObservableType {
        switch strategy {
        case .first:
            return flatMapFirst(selector)
        case .latest:
            return flatMapLatest(selector)
        }
    }
}
