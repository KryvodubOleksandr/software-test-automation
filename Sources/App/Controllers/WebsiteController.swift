import Vapor
import Fluent

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
        
        let protectedRoutes = authSessionsRoutes.grouped(User.redirectMiddleware(path: "/login"))
        protectedRoutes.get(use: indexHandler)
        protectedRoutes.get("posts", "create", use: renderCreatePostHandler)
        protectedRoutes.post("posts", "create", use: createPostHandler)
        
        protectedRoutes.post("posts", ":postID", "delete", use: deletePostHandler)
        protectedRoutes.post("posts", ":postID", use: createCommentHandler)
    }
    
    func indexHandler(_ req: Request) -> EventLoopFuture<View> {
        Post.query(on: req.db).all().flatMap { posts in
            let userLoggedIn = req.auth.has(User.self)
            let showCookieMessage = req.cookies["cookies-accepted"] == nil
            var context = IndexContext(title: "Home page", posts: posts, userLoggedIn: userLoggedIn, showCookieMessage: showCookieMessage, message: nil)
            if let message = req.query[String.self, at: "message"] {
                context.message = message
            }
            return req.view.render("index", context)
        }
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
}

struct IndexContext: Encodable {
    let title: String
    let posts: [Post]
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
