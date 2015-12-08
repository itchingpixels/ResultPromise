//
//  ResultPromise.swift
//  ResultPromise
//
//  Created by Mark Aron Szulyovszky on 19/11/2015.
//  Copyright © 2015 Mark Aron Szulyovszky. All rights reserved.
//

import Foundation

enum FutureError: ErrorType {
  case Fail
}


enum ResultPromiseStatus { case Pending, Fulfilled }


func createPromise<T>(operation: (completed:(result: Result<T>) -> Void) -> Void) -> ResultPromise<T> {
  let promise = ResultPromise(operation: operation)
  promise.executeOperation()
  return promise
}



class ResultPromise<T> {
  
  private var operationBlock: ((completed:(result: Result<T>) -> Void) -> Void)?
  private var thenBlock: ((value: T) ->  T)?
  private var finallyBlock: ((value: T) ->  Void)?
  private var flatMapBlock: ((value: T) ->  ResultPromise<T>)?
  private var catchBlock: ((error: ErrorType) -> Void)?
  
  private var nextFuture: ResultPromise<T>?
  
  func then(then: (value: T) -> T) -> ResultPromise {
    self.nextFuture = ResultPromise(then: then)
    return self.nextFuture!
  }
  
  func flatMap(flatMap: (value: T) -> ResultPromise<T>) -> ResultPromise {
    self.nextFuture = ResultPromise(flatMap: flatMap)
    return self.nextFuture!
  }
  
  func finally(finally: (value: T) -> Void) -> ResultPromise {
    self.nextFuture = ResultPromise(finally: finally)
    return self.nextFuture!
  }
  
  func catchAll(catchAll: (error: ErrorType) -> Void) -> ResultPromise {
    self.nextFuture = ResultPromise(catchAll: catchAll)
    return self.nextFuture!
  }
  
  private init(operation: (completed:(result: Result<T>) -> Void) -> Void) { self.operationBlock = operation }
  
  private init(finally: (T -> Void)) { self.finallyBlock = finally }
  
  private init(then: (T -> T)) { self.thenBlock = then }
  
  private init(flatMap: (T ->  ResultPromise<T>)) { self.flatMapBlock = flatMap }
  
  private init(catchAll: (ErrorType -> Void)) { self.catchBlock = catchAll }
  
}

private extension ResultPromise {
  
  func executeOperation() {
    func complete(result: Result<T>) {
      self.nextFuture?.executeNext(result)
    }

    self.operationBlock?(completed: complete)
  }
  
  
  func executeNext(result: Result<T>) {
    
    switch result {
    case .Success(let value):
      if let newValue = self.thenBlock?(value: value) {
        self.nextFuture?.executeNext(.Success(newValue))
      }
      
      if let nestedFuture = self.flatMapBlock?(value: value) {
        nestedFuture.nextFuture = self.nextFuture
      }
      
      if let finallyBlock = self.finallyBlock {
        finallyBlock(value: value)
      }
      
    case .Error(let error):
      
      if let catchBlock = catchBlock {
        catchBlock(error: error)
      } else {
        self.nextFuture?.executeNext(result)
      }
      
    }
  }
}