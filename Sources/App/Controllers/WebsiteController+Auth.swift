//
//  WebsiteController+Auth.swift
//  
//
//  Created by Alexander Sharko on 08.05.2023.
//

import Vapor
import Fluent
import SendGrid

extension WebsiteController {
    func loginHandler(_ req: Request) throws -> EventLoopFuture<Response> {
        let context: LoginContext
        if let error = req.query[Bool.self, at: "error"], error {
            context = LoginContext(loginError: true)
        } else {
            context = LoginContext()
        }
        return req.view.render("login", context).encodeResponse(for: req).map { response in
            return response
        }
    }
    
    func loginPostHandler(_ req: Request) throws -> EventLoopFuture<Response> {
        if req.auth.has(User.self) {
            return req.eventLoop.future(req.redirect(to: "/"))
        } else {
            let context = LoginContext(loginError: true)
            return req.view.render("login", context).encodeResponse(for: req).map { response in
                return response
            }
        }
    }
    
    func logoutHandler(_ req: Request) -> Response {
        req.auth.logout(User.self)
        return req.redirect(to: "/login")
    }
    
    func registerHandler(_ req: Request) throws -> EventLoopFuture<Response> {
        let context: RegisterContext
        if let message = req.query[String.self, at: "message"] {
            context = RegisterContext(message: message)
        } else {
            context = RegisterContext()
        }
        return req.view.render("register", context).encodeResponse(for: req).map { response in
            return response
        }
    }
    
    func registerPostHandler(_ req: Request) throws -> EventLoopFuture<Response> {
        do {
            try RegisterData.validate(content: req)
        } catch let error as ValidationsError {
            let message = error.description.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Unknown error"
            return req.eventLoop.future(req.redirect(to: "/register?message=\(message)"))
        }
        let data = try req.content.decode(RegisterData.self)
        let password = try Bcrypt.hash(data.password)
        let user = User(
            username: data.username,
            password: password,
            email: data.email
        )
        return user.save(on: req.db).map {
            req.auth.login(user)
            return req.redirect(to: "/")
        }
    }
}

struct LoginContext: Encodable {
    let title = "Log In"
    let loginError: Bool
    
    init(loginError: Bool = false) {
        self.loginError = loginError
    }
}

struct RegisterContext: Encodable {
    let title = "Register"
    let message: String?
    
    init(message: String? = nil) {
        self.message = message
    }
}

struct RegisterData: Content {
    let username: String
    let password: String
    let confirmPassword: String
    let email: String
}

extension RegisterData: Validatable {
    public static func validations(_ validations: inout Validations) {
        validations.add("username", as: String.self, is: .alphanumeric && .count(3...))
        validations.add("password", as: String.self, is: .count(8...))
        validations.add("email", as: String.self, is: .email)
    }
}
