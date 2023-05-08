import Vapor
import Fluent
import SendGrid

struct WebsiteController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let authSessionsRoutes = routes.grouped(User.sessionAuthenticator())
        authSessionsRoutes.get("login", use: loginHandler)
        let credentialsAuthRoutes = authSessionsRoutes.grouped(User.credentialsAuthenticator())
        credentialsAuthRoutes.post("login", use: loginPostHandler)
        authSessionsRoutes.post("logout", use: logoutHandler)
        authSessionsRoutes.get("register", use: registerHandler)
        authSessionsRoutes.post("register", use: registerPostHandler)
        
        authSessionsRoutes.get("posts", ":postID", use: postHandler)
        authSessionsRoutes.get("users", ":userID", use: userHandler)
        authSessionsRoutes.get("forgottenPassword", use: forgottenPasswordHandler)
        authSessionsRoutes.post("forgottenPassword", use: forgottenPasswordPostHandler)
        authSessionsRoutes.get("resetPassword", use: resetPasswordHandler)
        authSessionsRoutes.post("resetPassword", use: resetPasswordPostHandler)
        
        let protectedRoutes = authSessionsRoutes.grouped(User.redirectMiddleware(path: "/login"))
        protectedRoutes.get(use: indexHandler)
        protectedRoutes.get("posts", "create", use: renderCreatePostHandler)
        protectedRoutes.post("posts", "create", use: createPostHandler)
        
        protectedRoutes.post("posts", ":postID", "delete", use: deletePostHandler)
        protectedRoutes.post("posts", ":postID", use: createCommentHandler)
    }
    
    func indexHandler(_ req: Request) async throws -> View {
        let userLoggedIn = req.auth.has(User.self)
        let showCookieMessage = req.cookies["cookies-accepted"] == nil
        let posts = try await Post.query(on: req.db).all()
        
        var postsWithComments: [PostWithComments] = []
        for post in posts {
            let comments = try await post.$comments.get(on: req.db)
            postsWithComments.append(.init(post: post, comments: comments))
        }
        
        var context = IndexContext(
            title: "Home page",
            posts: postsWithComments,
            userLoggedIn: userLoggedIn,
            showCookieMessage: showCookieMessage,
            message: nil
        )
        if let message = req.query[String.self, at: "message"] {
            context.message = message
        }
        return try await req.view.render("index", context)
    }
    
    func postHandler(_ req: Request) -> EventLoopFuture<View> {
        Post.find(req.parameters.get("postID"), on: req.db).unwrap(or: Abort(.notFound)).flatMap { post in
            let userFuture = post.$user.get(on: req.db)
            let commentsFuture = post.$comments.query(on: req.db).all()
            return userFuture.and(commentsFuture).flatMap { user, comments in
                let context = PostContext(
                    title: post.title,
                    post: post,
                    user: user,
                    comments: comments)
                return req.view.render("post", context)
            }
        }
    }
    
    func userHandler(_ req: Request) -> EventLoopFuture<View> {
        User.find(req.parameters.get("userID"), on: req.db).unwrap(or: Abort(.notFound)).flatMap { user in
            user.$posts.get(on: req.db).flatMap { posts in
                let context = UserContext(title: user.username, user: user, posts: posts)
                return req.view.render("user", context)
            }
        }
    }
    
    func renderCreatePostHandler(_ req: Request) -> EventLoopFuture<View> {
        let token = [UInt8].random(count: 16).base64
        let context = CreatePostContext(csrfToken: token)
        req.session.data["CSRF_TOKEN"] = token
        return req.view.render("createPost", context)
    }
    
    func createPostHandler(_ req: Request) throws -> EventLoopFuture<Response> {
        let data = try req.content.decode(CreatePostFormData.self)
        let user = try req.auth.require(User.self)
        
        let expectedToken = req.session.data["CSRF_TOKEN"]
        req.session.data["CSRF_TOKEN"] = nil
        guard
            let csrfToken = data.csrfToken,
            expectedToken == csrfToken
        else {
            throw Abort(.badRequest)
        }
        
        let post = try Post(title: data.title, description: data.description, body: data.body, userID: user.requireID())
        let message = "Blog Post posted successfully!"
        let redirect = req.redirect(to: "/?message=\(message)")
        return post.save(on: req.db).transform(to: redirect)
    }
    
    func createCommentHandler(_ req: Request) throws -> EventLoopFuture<Response> {
        let data = try req.content.decode(CreateCommentFormData.self)
        //        let user = try req.auth.require(User.self)
        
        //        let expectedToken = req.session.data["CSRF_TOKEN"]
        //        req.session.data["CSRF_TOKEN"] = nil
        //        guard
        //            let csrfToken = data.csrfToken,
        //            expectedToken == csrfToken
        //        else {
        //            throw Abort(.badRequest)
        //        }
        
        let comment = Comment(name: data.name, message: data.message, postID: data.postId)
        let message = "Comment added to the Post successfully!"
        let redirect = req.redirect(to: "/?message=\(message)")
        return comment.save(on: req.db).transform(to: redirect)
    }
    
    func deletePostHandler(_ req: Request) -> EventLoopFuture<Response> {
        Post.find(req.parameters.get("postID"), on: req.db).unwrap(or: Abort(.notFound)).flatMap { post in
            post.delete(on: req.db).transform(to: req.redirect(to: "/"))
        }
    }
    
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

struct IndexContext: Encodable {
    let title: String
    let posts: [PostWithComments]
    let userLoggedIn: Bool
    let showCookieMessage: Bool
    var message: String?
}

struct PostContext: Encodable {
    let title: String
    let post: Post
    let user: User
    let comments: [Comment]
}

struct PostWithComments: Encodable {
    let post: Post
    let comments: [Comment]
}

struct UserContext: Encodable {
    let title: String
    let user: User
    let posts: [Post]
}

struct CreatePostContext: Encodable {
    let title = "Add New Post"
    let csrfToken: String
}

struct CreatePostFormData: Content {
    let title: String
    let description: String
    let body: String
    let csrfToken: String?
}

struct CreateCommentFormData: Content {
    let name: String
    let message: String
    let postId: Post.IDValue
    let csrfToken: String?
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

struct CreatePostData: Content {
    let title: String
    let description: String
    let body: String
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
