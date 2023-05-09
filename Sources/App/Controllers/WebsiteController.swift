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
        protectedRoutes.get("profile", use: profileHandler)
        protectedRoutes.get("profile", "edit", use: editProfileHandler)
        protectedRoutes.post("profile", "edit", use: editProfilePostHandler)
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
    
    func userHandler(_ req: Request) -> EventLoopFuture<View> {
        User.find(req.parameters.get("userID"), on: req.db).unwrap(or: Abort(.notFound)).flatMap { user in
            user.$posts.get(on: req.db).flatMap { posts in
                let context = UserContext(title: user.username, user: user, posts: posts)
                return req.view.render("user", context)
            }
        }
    }
    
    func profileHandler(_ req: Request) async throws -> View {
        if let user = req.auth.get(User.self) {
            let context = ProfileContext(title: "My Profile", user: user, userLoggedIn: true)
            return try await req.view.render("user", context)
        } else {
            return try await req.view.render("/login")
        }
    }
    
    func editProfileHandler(_ req: Request) async throws -> View {
        if let user = req.auth.get(User.self) {
            let context = EditProfileContext(user: user, userLoggedIn: true)
            return try await req.view.render("editProfile", context)
        } else {
            return try await req.view.render("login")
        }
    }
    
    func editProfilePostHandler(_ req: Request) async throws -> Response {
        if var user = req.auth.get(User.self) {
            let updateData = try req.content.decode(EditProfileFormData.self)
            user.firstname = updateData.firstname
            user.lastname = updateData.lastname
            user.age = updateData.age
            user.gender = updateData.gender
            user.address = updateData.address
            user.website = updateData.website

            try await user.save(on: req.db)
            let message = "Profile updated successfully!"
            return req.redirect(to: "/?message=\(message)")
        } else {
            return req.redirect(to: "login")
        }
    }
}

struct IndexContext: Encodable {
    let title: String
    let posts: [PostWithComments]
    let userLoggedIn: Bool
    let showCookieMessage: Bool
    var message: String?
}

struct UserContext: Encodable {
    let title: String
    let user: User
    let posts: [Post]
}

struct ProfileContext: Encodable {
    let title: String
    let user: User
    let userLoggedIn: Bool
}

struct EditProfileContext: Encodable {
    let title = "My Profile"
    let user: User
    let userLoggedIn: Bool
}

struct EditProfileFormData: Content {
    let firstname: String
    let lastname: String
    let age: String
    let gender: String
    let address: String
    let website: String
}
