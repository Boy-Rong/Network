//
//  ViewController.swift
//  RHNetwork
//
//  Created by 495929699g@gmail.com on 04/19/2019.
//  Copyright (c) 2019 495929699g@gmail.com. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}


/**
 import RxSwift
 import RxSwiftExtensions
 import Network
 
 func jr_page<RequestParams,Result,Value,NewValue>(
 frist: Observable<Void>,
 next: Observable<Void>,
 params: Observable<RequestParams>,
 requestFromParams: @escaping (RequestParams,Int) -> Observable<Result>,
 valuesFromResult: @escaping (Result) -> (Value),
 transform: @escaping (Value) -> (NewValue))
 ->
 (values: Observable<[NewValue]>,
 isLoading: Observable<Bool>,
 total: Observable<Int>) {
 var page = 1
 let isRefresh = Observable.merge(frist.mapValue(true), next.mapValue(false)
 ).startWith(true)
 let requestPage = isRefresh.map { $0 ? 1 : (page + 1) }
 let loadState = PublishSubject<PageLoadState>()
 let error = PublishSubject<NetworkError>()
 //let indicator = ActivityIndicator()
 frist.flatMap {_ in
 next.startWith(())
 .withLatestFrom(params, requestPage)
 .flatMapLatest({ (_params,_page) -> Observable<NewValue> in
 return requestFromParams(_params, _page)
 .shareOnce()
 .doNext {
 
 }
 .observeOn(transformScheduler)
 .map(valuesFromResult)
 .map(transform)
 })
 }
 
 }
 
 
 private let transformScheduler = ConcurrentDispatchQueueScheduler(qos: .default)

 */
