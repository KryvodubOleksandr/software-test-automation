//
//  ResetPasswordToken.swift
//  
//
//  Created by Alexander Sharko on 08.05.2023.
//

import Fluent
import Vapor

final class ResetPasswordToken: Model, Content {
    static let schema = "resetPasswordTokens"
    
    @ID
    var id: UUID?
    
    @Field(key: "token")
    var token: String
    
    @Parent(key: "userID")
    var user: User
    
    init() {}
    
    init(id: UUID? = nil, token: String, userID: User.IDValue) {
        self.id = id
        self.token = token
        self.$user.id = userID
    }
}
