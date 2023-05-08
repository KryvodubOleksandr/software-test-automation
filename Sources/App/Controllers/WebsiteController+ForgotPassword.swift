//
//  WebsiteController+ForgotPassword.swift
//  
//
//  Created by Alexander Sharko on 08.05.2023.
//

import Vapor
import Fluent
import SendGrid

extension WebsiteController {
    func forgottenPasswordHandler(_ req: Request) throws -> EventLoopFuture<View> {
        req.view.render("forgottenPassword", ["title": "Reset Your Password"])
    }
    
    func forgottenPasswordPostHandler(_ req: Request) throws -> EventLoopFuture<View> {
        let email = try req.content.get(String.self, at: "email")
        return User.query(on: req.db).filter(\.$email == email).first().flatMap { user in
            guard let user = user else {
                return req.view.render("forgottenPasswordConfirmed", ["title": "Password Reset Email Sent"])
            }
            let resetTokenString = Data([UInt8].random(count: 32)).base32EncodedString()
            let resetToken: ResetPasswordToken
            do {
                resetToken = try ResetPasswordToken(token: resetTokenString, userID: user.requireID())
            } catch {
                return req.eventLoop.future(error: error)
            }
            return resetToken.save(on: req.db).flatMap {
                let emailContent = """
              <p>You've requested to reset your password. <a
              href="http://localhost:8080/resetPassword?\
              token=\(resetTokenString)">
              Click here</a> to reset your password.</p>
              """
                let emailAddress = EmailAddress(email: user.email, name: user.username)
                let fromEmail = EmailAddress(
                    email: "moneyforthenothing@outlook.com",
                    name: "Kryvodub_Software_Test_Automation"
                )
                let emailConfig = Personalization(to: [emailAddress], subject: "Reset Your Password")
                let email = SendGridEmail(
                    personalizations: [emailConfig],
                    from: fromEmail,
                    content: [["type": "text/html", "value": emailContent]])
                let emailSend: EventLoopFuture<Void>
                do {
                    emailSend = try req.application.sendgrid.client.send(email: email, on: req.eventLoop)
                } catch {
                    return req.eventLoop.future(error: error)
                }
                return emailSend.flatMap {
                    req.view.render("forgottenPasswordConfirmed", ["title": "Password Reset Email Sent"])
                }
            }
        }
    }
    
    func resetPasswordHandler(_ req: Request) -> EventLoopFuture<View> {
        guard let token = try? req.query.get(String.self, at: "token") else {
            return req.view.render("resetPassword", ResetPasswordContext(error: true))
        }
        return ResetPasswordToken.query(on: req.db).filter(\.$token == token).first()
            .unwrap(or: Abort.redirect(to: "/"))
            .flatMap { token in
                token.$user.get(on: req.db).flatMap { user in
                    do {
                        try req.session.set("ResetPasswordUser", to: user)
                    } catch {
                        return req.eventLoop.future(error: error)
                    }
                    return token.delete(on: req.db)
                }
            }.flatMap {
                req.view.render("resetPassword", ResetPasswordContext()
                )
            }
    }
    
    func resetPasswordPostHandler(_ req: Request) throws -> EventLoopFuture<Response> {
        let data = try req.content.decode(ResetPasswordData.self)
        guard data.password == data.confirmPassword else {
            return req.view.render("resetPassword", ResetPasswordContext(error: true))
                .encodeResponse(for: req)
        }
        let resetPasswordUser = try req.session.get("ResetPasswordUser", as: User.self)
        req.session.data["ResetPasswordUser"] = nil
        let newPassword = try Bcrypt.hash(data.password)
        return try User.query(on: req.db)
            .filter(\.$id == resetPasswordUser.requireID())
            .set(\.$password, to: newPassword)
            .update()
            .transform(to: req.redirect(to: "/login"))
    }
}

struct ResetPasswordContext: Encodable {
    let title = "Reset Password"
    let error: Bool?
    
    init(error: Bool? = false) {
        self.error = error
    }
}

struct ResetPasswordData: Content {
    let password: String
    let confirmPassword: String
}

extension Session {
    public func get<T>(_ key: String, as type: T.Type) throws -> T where T: Codable {
        guard let stored = data[key] else {
            if _isOptional(T.self) { return Optional<Void>.none as! T }
            throw Abort(.internalServerError, reason: "No element found in session with ket '\(key)'")
        }
        return try JSONDecoder().decode(T.self, from: Data(stored.utf8))
    }
    
    public func set<T>(_ key: String, to data: T) throws where T: Codable {
        let val = try String(data: JSONEncoder().encode(data), encoding: .utf8)
        self.data[key] = val
    }
}
