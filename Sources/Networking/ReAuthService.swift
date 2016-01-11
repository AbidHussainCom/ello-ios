//
//  AuthService.swift
//  Ello
//
//  Created by Sean Dougherty on 11/30/14.
//  Copyright (c) 2014 Ello. All rights reserved.
//

import Moya
import SwiftyJSON

private let operationQueue = NSOperationQueue.mainQueue()
private var currentReauthOperation: NSOperation?
private var reauthResult: (Bool, ElloFailure?)?

public class ReAuthService: NSObject {

    public func reAuthenticate(success success: AuthSuccessCompletion, failure: ElloFailureCompletion) {
        guard !AppSetup.sharedState.isTesting else {
            _reAuthenticateToken(success: success, failure: failure)
            return
        }

        // cheap way to make sure these updates all happen on one queue
        nextTick {
            let reauthOperation: NSOperation
            if let currentReauthOperation = currentReauthOperation {
                // establishes serial queue by having all future auth requests 
                // require the "current" op to be complete
                reauthOperation = AsyncOperation(block: { done in
                    let result = reauthResult ?? (true, nil)
                    if result.0 == true {
                        success()
                    }
                    else {
                        failure(error: result.1!.error, statusCode: result.1!.statusCode)
                    }
                    done()
                })
                reauthOperation.addDependency(currentReauthOperation)
            }
            else {
                reauthOperation = AsyncOperation(block: { done in
                    self._reAuthenticateToken(success: {
                        success()
                        currentReauthOperation = nil
                        done()
                    }, failure: { (error, statusCode) in
                        failure(error: error, statusCode: statusCode)
                        currentReauthOperation = nil
                        done()
                    })
                })
                currentReauthOperation = reauthOperation
            }

            operationQueue.addOperation(reauthOperation)
        }
    }

    private func _reAuthenticateToken(success success: AuthSuccessCompletion, failure: ElloFailureCompletion) {
        let endpoint: ElloAPI
        let token = AuthToken()
        let prevToken = token.token
        let refreshToken = token.refreshToken
        if let refreshToken = refreshToken where token.isPresent && token.isAuthenticated {
            log("prev token: \(prevToken), requesting new token with: \(refreshToken)")
            endpoint = .ReAuth(token: refreshToken)
        }
        else {
            endpoint = .AnonymousCredentials
        }

        ElloProvider.sharedProvider.request(endpoint) { (result) in
            switch result {
            case let .Success(moyaResponse):
                let statusCode = moyaResponse.statusCode
                let data = moyaResponse.data

                switch statusCode {
                case 200...299:
                    log("refreshToken: \(refreshToken), received new token: \(token.token)")
                    self.storeToken(data, endpoint: endpoint)
                    reauthResult = (true, nil)
                    success()
                    return
                default:
                    break
                }

                log("refreshToken: \(refreshToken), failed to receive new token")
                self._reAuthenticateUsername(success: success, failure: failure)
            case let .Failure(error):
                reauthResult = (false, (error: error as NSError, statusCode: nil))
                failure(error: error as NSError, statusCode: nil)
            }
        }
    }

    private func _reAuthenticateUsername(success success: AuthSuccessCompletion, failure: ElloFailureCompletion) {
        var token = AuthToken()
        if let email = token.username, password = token.password {
            let endpoint: ElloAPI = .Auth(email: email, password: password)
            ElloProvider.sharedProvider.request(endpoint) { (result) in
                switch result {
                case let .Success(moyaResponse):
                    switch moyaResponse.statusCode {
                    case 200...299:
                        reauthResult = (true, nil)
                        self.storeToken(moyaResponse.data, endpoint: endpoint)
                        log("created new token: \(AuthToken().token)")
                        success()
                    default:
                        let elloError = ElloProvider.generateElloError(moyaResponse.data, error: nil, statusCode: moyaResponse.statusCode)
                        reauthResult = (false, (error: elloError, statusCode: moyaResponse.statusCode))
                        failure(error: elloError, statusCode: moyaResponse.statusCode)
                    }
                case let .Failure(error):
                    reauthResult = (false, (error: error as NSError, statusCode: nil))
                    failure(error: error as NSError, statusCode: nil)
                }
            }
        }
        else {
            ElloProvider.failedToMapObjects(failure)
        }
    }

    private func storeToken(data: NSData, endpoint: ElloAPI) {
        var authToken = AuthToken()

        switch endpoint {
        case .AnonymousCredentials: authToken.isAuthenticated = false
        default: authToken.isAuthenticated = true
        }

        do {
            let json = try JSON(data: data)
            authToken.token = json["access_token"].stringValue
            authToken.type = json["token_type"].stringValue
            authToken.refreshToken = json["refresh_token"].stringValue
        }
        catch {
            log("failed to create JSON and store authToken")
        }
    }
}