//
//  WhenTests.swift
//  PromissoryTests
//
//  Created by Ballard, Kevin on 12/20/17.
//  Copyright © 2017 Kevin Ballard. All rights reserved.
//

import XCTest
import Promissory

final class WhenArrayTests: XCTestCase {
    func testWhen() {
        let promises = (1...5).map({ x -> Promise<Int,String> in
            Promise(on: .utility, { (resolver) in
                resolver.fulfill(x * 2)
            })
        })
        let promise = when(fulfilled: promises)
        let expectation = XCTestExpectation(onSuccess: promise, handler: { (values) in
            XCTAssertEqual(values, [2,4,6,8,10])
        })
        wait(for: [expectation], timeout: 1)
    }
    
    func testWhenRejected() {
        let promises = (1...5).map({ x -> Promise<Int,String> in
            Promise(on: .utility, { (resolver) in
                if x == 3 {
                    resolver.reject("error")
                } else {
                    resolver.fulfill(x * 2)
                }
            })
        })
        let promise = when(fulfilled: promises)
        let expectation = XCTestExpectation(onError: promise, expectedError: "error")
        wait(for: [expectation], timeout: 1)
    }
    
    func testWhenCancelled() {
        let promises = (1...5).map({ x -> Promise<Int,String> in
            Promise(on: .utility, { (resolver) in
                if x == 3 {
                    resolver.cancel()
                } else {
                    resolver.fulfill(x * 2)
                }
            })
        })
        let promise = when(fulfilled: promises)
        let expectation = XCTestExpectation(onCancel: promise)
        wait(for: [expectation], timeout: 1)
    }
    
    func testWhenRejectedWithCancelOnFailureCancelsInput() {
        let sema = DispatchSemaphore(value: 1)
        sema.wait()
        let promisesAndExpectations = (1...5).map({ x -> (Promise<Int,String>, XCTestExpectation) in
            let expectation = XCTestExpectation(description: "promise \(x)")
            let promise = Promise<Int,String>(on: .utility, { (resolver) in
                if x == 3 {
                    resolver.reject("error")
                    expectation.fulfill()
                } else {
                    resolver.onRequestCancel(on: .immediate) { (resolver) in
                        resolver.cancel()
                    }
                    sema.wait()
                    sema.signal()
                    resolver.fulfill(x * 2)
                }
            })
            if x != 3 {
                expectation.fulfill(onCancel: promise)
            }
            return (promise, expectation)
        })
        let promises = promisesAndExpectations.map({ $0.0 })
        let expectations = promisesAndExpectations.map({ $0.1 })
        let promise = when(fulfilled: promises, cancelOnFailure: true)
        let expectation = XCTestExpectation(onError: promise, expectedError: "error")
        wait(for: [expectation], timeout: 1)
        sema.signal() // let the promises empty out
        wait(for: expectations, timeout: 1)
    }
    
    func testWhenCancelledWithCancelOnFailureCancelsInput() {
        let sema = DispatchSemaphore(value: 1)
        sema.wait()
        let promisesAndExpectations = (1...5).map({ x -> (Promise<Int,String>, XCTestExpectation) in
            let expectation = XCTestExpectation(description: "promise \(x)")
            let promise = Promise<Int,String>(on: .utility, { (resolver) in
                if x == 3 {
                    resolver.cancel()
                    expectation.fulfill()
                } else {
                    resolver.onRequestCancel(on: .immediate) { (resolver) in
                        resolver.cancel()
                    }
                    sema.wait()
                    sema.signal()
                    resolver.fulfill(x * 2)
                }
            })
            if x != 3 {
                expectation.fulfill(onCancel: promise)
            }
            return (promise, expectation)
        })
        let promises = promisesAndExpectations.map({ $0.0 })
        let expectations = promisesAndExpectations.map({ $0.1 })
        let promise = when(fulfilled: promises, cancelOnFailure: true)
        let expectation = XCTestExpectation(onCancel: promise)
        wait(for: [expectation], timeout: 1)
        sema.signal() // let the promises empty out
        wait(for: expectations, timeout: 1)
    }
    
    func testWhenCancelledByDefaultDoesntCancelInput() {
        let sema = DispatchSemaphore(value: 1)
        sema.wait()
        let promisesAndExpectations = (1...5).map({ x -> (Promise<Int,String>, XCTestExpectation) in
            let expectation = XCTestExpectation(description: "promise \(x)")
            let promise = Promise<Int,String>(on: .utility, { (resolver) in
                if x == 3 {
                    resolver.cancel()
                    expectation.fulfill()
                } else {
                    resolver.onRequestCancel(on: .immediate) { (resolver) in
                        resolver.cancel()
                    }
                    sema.wait()
                    sema.signal()
                    resolver.fulfill(x * 2)
                }
            })
            if x != 3 {
                expectation.fulfill(onSuccess: promise, expectedValue: x * 2)
            }
            return (promise, expectation)
        })
        let promises = promisesAndExpectations.map({ $0.0 })
        let expectations = promisesAndExpectations.map({ $0.1 })
        let promise = when(fulfilled: promises)
        let expectation = XCTestExpectation(onCancel: promise)
        wait(for: [expectation], timeout: 1)
        sema.signal() // let the promises empty out
        wait(for: expectations, timeout: 1)
    }
    
    func testWhenEmptyInput() {
        let promise: Promise<[Int],String> = when(fulfilled: [])
        let expectation = XCTestExpectation(onSuccess: promise, handler: { (values) in
            XCTAssertEqual([], values)
        })
        wait(for: [expectation], timeout: 1)
    }
    
    func testWhenDuplicatePromise() {
        let dummy = Promise<Int,String>(fulfilled: 42)
        let promise: Promise<[Int],String> = when(fulfilled: [dummy, dummy, dummy])
        let expectation = XCTestExpectation(onSuccess: promise, handler: { (values) in
            XCTAssertEqual(values, [42, 42, 42])
        })
        wait(for: [expectation], timeout: 1)
    }
}

final class WhenTupleTests: XCTestCase {
    func testWhen() {
        func helper<Value>(n: Int, when: ([Promise<Int,String>]) -> Promise<Value,String>, splat: @escaping (Value) -> [Int]) {
            let promises = (1...n).map({ x -> Promise<Int,String> in
                Promise(on: .utility, { (resolver) in
                    resolver.fulfill(x * 2)
                })
            })
            let promise = when(promises)
            let expectation = XCTestExpectation(onSuccess: promise, handler: { (values) in
                let ary = splat(values)
                XCTAssertEqual(ary, Array([2,4,6,8,10,12].prefix(ary.count)))
            })
            wait(for: [expectation], timeout: 1)
        }
        helper(n: 6, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3], ps[4], ps[5]) }, splat: splat)
        helper(n: 5, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3], ps[4]) }, splat: splat)
        helper(n: 4, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3]) }, splat: splat)
        helper(n: 3, when: { ps in when(fulfilled: ps[0], ps[1], ps[2]) }, splat: splat)
        helper(n: 2, when: { ps in when(fulfilled: ps[0], ps[1]) }, splat: splat)
    }
    
    func testWhenRejected() {
        func helper<Value>(n: Int, when: ([Promise<Int,String>]) -> Promise<Value,String>) {
            let promises = (1...n).map({ x -> Promise<Int,String> in
                Promise(on: .utility, { (resolver) in
                    if x == 2 {
                        resolver.reject("error")
                    } else {
                        resolver.fulfill(x * 2)
                    }
                })
            })
            let promise = when(promises)
            let expectation = XCTestExpectation(onError: promise, expectedError: "error")
            wait(for: [expectation], timeout: 1)
        }
        helper(n: 6, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3], ps[4], ps[5]) })
        helper(n: 5, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3], ps[4]) })
        helper(n: 4, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3]) })
        helper(n: 3, when: { ps in when(fulfilled: ps[0], ps[1], ps[2]) })
        helper(n: 2, when: { ps in when(fulfilled: ps[0], ps[1]) })
    }
    
    func testWhenCancelled() {
        func helper<Value>(n: Int, when: ([Promise<Int,String>]) -> Promise<Value,String>) {
            let promises = (1...n).map({ x -> Promise<Int,String> in
                Promise(on: .utility, { (resolver) in
                    if x == 2 {
                        resolver.cancel()
                    } else {
                        resolver.fulfill(x * 2)
                    }
                })
            })
            let promise = when(promises)
            let expectation = XCTestExpectation(onCancel: promise)
            wait(for: [expectation], timeout: 1)
        }
        helper(n: 6, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3], ps[4], ps[5]) })
        helper(n: 5, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3], ps[4]) })
        helper(n: 4, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3]) })
        helper(n: 3, when: { ps in when(fulfilled: ps[0], ps[1], ps[2]) })
        helper(n: 2, when: { ps in when(fulfilled: ps[0], ps[1]) })
    }
    
    func testWhenRejectedWithCancelOnFailureCancelsInput() {
        func helper<Value>(n: Int, when: ([Promise<Int,String>]) -> Promise<Value,String>) {
            let sema = DispatchSemaphore(value: 1)
            sema.wait()
            let promisesAndExpectations = (1...n).map({ x -> (Promise<Int,String>, XCTestExpectation) in
                let expectation = XCTestExpectation(description: "promise \(x)")
                let promise = Promise<Int,String>(on: .utility, { (resolver) in
                    if x == 2 {
                        resolver.reject("error")
                        expectation.fulfill()
                    } else {
                        resolver.onRequestCancel(on: .immediate) { (resolver) in
                            resolver.cancel()
                        }
                        sema.wait()
                        sema.signal()
                        resolver.fulfill(x * 2)
                    }
                })
                if x != 2 {
                    expectation.fulfill(onCancel: promise)
                }
                return (promise, expectation)
            })
            let promises = promisesAndExpectations.map({ $0.0 })
            let expectations = promisesAndExpectations.map({ $0.1 })
            let promise = when(promises)
            let expectation = XCTestExpectation(description: "promise resolved")
            promise.always(on: .utility, { _ in expectation.fulfill() })
            wait(for: [expectation], timeout: 1)
            sema.signal() // let the promises empty out
            wait(for: expectations, timeout: 1)
        }
        helper(n: 6, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3], ps[4], ps[5], cancelOnFailure: true) })
        helper(n: 5, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3], ps[4], cancelOnFailure: true) })
        helper(n: 4, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3], cancelOnFailure: true) })
        helper(n: 3, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], cancelOnFailure: true) })
        helper(n: 2, when: { ps in when(fulfilled: ps[0], ps[1], cancelOnFailure: true) })
    }
    
    func testWhenCancelledWithCancelOnFailureCancelsInput() {
        func helper<Value>(n: Int, when: ([Promise<Int,String>]) -> Promise<Value,String>) {
            let sema = DispatchSemaphore(value: 1)
            sema.wait()
            let promisesAndExpectations = (1...n).map({ x -> (Promise<Int,String>, XCTestExpectation) in
                let expectation = XCTestExpectation(description: "promise \(x)")
                let promise = Promise<Int,String>(on: .utility, { (resolver) in
                    if x == 2 {
                        resolver.cancel()
                        expectation.fulfill()
                    } else {
                        resolver.onRequestCancel(on: .immediate) { (resolver) in
                            resolver.cancel()
                        }
                        sema.wait()
                        sema.signal()
                        resolver.fulfill(x * 2)
                    }
                })
                if x != 2 {
                    expectation.fulfill(onCancel: promise)
                }
                return (promise, expectation)
            })
            let promises = promisesAndExpectations.map({ $0.0 })
            let expectations = promisesAndExpectations.map({ $0.1 })
            let promise = when(promises)
            let expectation = XCTestExpectation(description: "promise resolved")
            promise.always(on: .utility, { _ in expectation.fulfill() })
            wait(for: [expectation], timeout: 1)
            sema.signal() // let the promises empty out
            wait(for: expectations, timeout: 1)
        }
        helper(n: 6, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3], ps[4], ps[5], cancelOnFailure: true) })
        helper(n: 5, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3], ps[4], cancelOnFailure: true) })
        helper(n: 4, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3], cancelOnFailure: true) })
        helper(n: 3, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], cancelOnFailure: true) })
        helper(n: 2, when: { ps in when(fulfilled: ps[0], ps[1], cancelOnFailure: true) })
    }
    
    func testWhenCancelledByDefaultDoesntCancelInput() {
        func helper<Value>(n: Int, when: ([Promise<Int,String>]) -> Promise<Value,String>) {
            let sema = DispatchSemaphore(value: 1)
            sema.wait()
            let promisesAndExpectations = (1...n).map({ x -> (Promise<Int,String>, XCTestExpectation) in
                let expectation = XCTestExpectation(description: "promise \(x)")
                let promise = Promise<Int,String>(on: .utility, { (resolver) in
                    if x == 2 {
                        resolver.cancel()
                        expectation.fulfill()
                    } else {
                        resolver.onRequestCancel(on: .immediate) { (resolver) in
                            resolver.cancel()
                        }
                        sema.wait()
                        sema.signal()
                        resolver.fulfill(x * 2)
                    }
                })
                if x != 2 {
                    expectation.fulfill(onSuccess: promise, expectedValue: x * 2)
                }
                return (promise, expectation)
            })
            let promises = promisesAndExpectations.map({ $0.0 })
            let expectations = promisesAndExpectations.map({ $0.1 })
            let promise = when(promises)
            let expectation = XCTestExpectation(description: "promise resolved")
            promise.always(on: .utility, { _ in expectation.fulfill() })
            wait(for: [expectation], timeout: 1)
            sema.signal() // let the promises empty out
            wait(for: expectations, timeout: 1)
        }
        helper(n: 6, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3], ps[4], ps[5]) })
        helper(n: 5, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3], ps[4]) })
        helper(n: 4, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3]) })
        helper(n: 3, when: { ps in when(fulfilled: ps[0], ps[1], ps[2]) })
        helper(n: 2, when: { ps in when(fulfilled: ps[0], ps[1]) })
    }
    
    func testWhenDuplicatePromise() {
        func helper<Value>(n: Int, when: ([Promise<Int,String>]) -> Promise<Value,String>, splat: @escaping (Value) -> [Int]) {
            let dummy = Promise<Int,String>(fulfilled: 42)
            let promises = (1...n).map({ _ in dummy })
            let promise = when(promises)
            let expectation = XCTestExpectation(onSuccess: promise, handler: { (values) in
                let ary = splat(values)
                XCTAssertEqual(ary, Array([42,42,42,42,42,42].prefix(ary.count)))
            })
            wait(for: [expectation], timeout: 1)
        }
        helper(n: 6, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3], ps[4], ps[5]) }, splat: splat)
        helper(n: 5, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3], ps[4]) }, splat: splat)
        helper(n: 4, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3]) }, splat: splat)
        helper(n: 3, when: { ps in when(fulfilled: ps[0], ps[1], ps[2]) }, splat: splat)
        helper(n: 2, when: { ps in when(fulfilled: ps[0], ps[1]) }, splat: splat)
    }
}

private func splat<T>(_ a: T, _ b: T, _ c: T, _ d: T, _ e: T, _ f: T) -> [T] {
    return [a,b,c,d,e,f]
}

private func splat<T>(_ a: T, _ b: T, _ c: T, _ d: T, _ e: T) -> [T] {
    return [a,b,c,d,e]
}

private func splat<T>(_ a: T, _ b: T, _ c: T, _ d: T) -> [T] {
    return [a,b,c,d]
}

private func splat<T>(_ a: T, _ b: T, _ c: T) -> [T] {
    return [a,b,c]
}

private func splat<T>(_ a: T, _ b: T) -> [T] {
    return [a,b]
}
