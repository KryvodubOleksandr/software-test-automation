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
    authSessionsRoutes.get("comments", ":commentID", use: commentHandler)
    
    let protectedRoutes = authSessionsRoutes.grouped(User.redirectMiddleware(path: "/login"))
    protectedRoutes.get(use: indexHandler)
    protectedRoutes.get("posts", "create", use: renderCreatePostHandler)
    protectedRoutes.post("posts", "create", use: createPostHandler)
    protectedRoutes.get("posts", ":postID", "edit", use: renderEditPostHandler)
    protectedRoutes.post("posts", ":postID", "edit", use: editPostHandler)
    protectedRoutes.post("posts", ":postID", "delete", use: deletePostHandler)
  }
  
  func indexHandler(_ req: Request) -> EventLoopFuture<View> {
    Post.query(on: req.db).all().flatMap { posts in
      let userLoggedIn = req.auth.has(User.self)
      let showCookieMessage = req.cookies["cookies-accepted"] == nil
      let context = IndexContext(title: "Home page", posts: posts, userLoggedIn: userLoggedIn, showCookieMessage: showCookieMessage)
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
  
  func commentHandler(_ req: Request) -> EventLoopFuture<View> {
    Comment.find(req.parameters.get("commentID"), on: req.db).unwrap(or: Abort(.notFound)).flatMap { comment in
      comment.$posts.get(on: req.db).flatMap { posts in
        let context = CommentContext(title: comment.name, comment: comment, posts: posts)
        return req.view.render("comment", context)
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
    return post.save(on: req.db).flatMap {
      guard let id = post.id else {
        return req.eventLoop.future(error: Abort(.internalServerError))
      }
      var commentSaves: [EventLoopFuture<Void>] = []
      for comment in data.comments ?? [] {
        commentSaves.append(Comment.addComment(comment, to: post, on: req))
      }
      let redirect = req.redirect(to: "/")
      return commentSaves.flatten(on: req.eventLoop).transform(to: redirect)
    }
  }
  
  func renderEditPostHandler(_ req: Request) -> EventLoopFuture<View> {
    return Post.find(req.parameters.get("postID"), on: req.db).unwrap(or: Abort(.notFound)).flatMap { post in
      post.$comments.get(on: req.db).flatMap { comments in
        let context = EditPostContext(post: post, comments: comments)
        return req.view.render("createPost", context)
      }
    }
  }
  
  func editPostHandler(_ req: Request) throws -> EventLoopFuture<Response> {
    let user = try req.auth.require(User.self)
    let userID = try user.requireID()
    let updateData = try req.content.decode(CreatePostFormData.self)
    return Post.find(req.parameters.get("postID"), on: req.db).unwrap(or: Abort(.notFound)).flatMap { post in
      post.title = updateData.title
      post.body = updateData.body
      post.$user.id = userID
      guard let id = post.id else {
        return req.eventLoop.future(error: Abort(.internalServerError))
      }
      return post.save(on: req.db).flatMap {
        post.$comments.get(on: req.db)
      }.flatMap { existingComments in
        let existingStringArray = existingComments.map {
          $0.name
        }
        
        let existingSet = Set<String>(existingStringArray)
        let newSet = Set<String>(updateData.comments ?? [])
        
        let commentsToAdd = newSet.subtracting(existingSet)
        let commentsToRemove = existingSet.subtracting(newSet)
        
        var commentResults: [EventLoopFuture<Void>] = []
        for newComment in commentsToAdd {
          commentResults.append(Comment.addComment(newComment, to: post, on: req))
        }
        
        for commentNameToRemove in commentsToRemove {
          let commentToRemove = existingComments.first {
            $0.name == commentNameToRemove
          }
          if let comment = commentToRemove {
            commentResults.append(
              post.$comments.detach(comment, on: req.db))
          }
        }
        
        let redirect = req.redirect(to: "/posts/\(id)")
        return commentResults.flatten(on: req.eventLoop).transform(to: redirect)
      }
    }
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
      password: password
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

struct CommentContext: Encodable {
  let title: String
  let comment: Comment
  let posts: [Post]
}

struct CreatePostContext: Encodable {
  let title = "Add New Post"
  let csrfToken: String
}

struct EditPostContext: Encodable {
  let title = "Edit Post"
  let post: Post
  let editing = true
  let comments: [Comment]
}

struct CreatePostFormData: Content {
  let title: String
  let description: String
  let body: String
  let comments: [String]?
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
}

extension RegisterData: Validatable {
  public static func validations(_ validations: inout Validations) {
    validations.add("username", as: String.self, is: .alphanumeric && .count(3...))
    validations.add("password", as: String.self, is: .count(8...))
    validations.add("zipCode", as: String.self, is: .zipCode, required: false)
  }
}

extension ValidatorResults {
  struct ZipCode {
    let isValidZipCode: Bool
  }
}

extension ValidatorResults.ZipCode: ValidatorResult {
  var isFailure: Bool {
    !isValidZipCode
  }

  var successDescription: String? {
    "is a valid zip code"
  }

  var failureDescription: String? {
    "is not a valid zip code"
  }
}

extension Validator where T == String {
  private static var zipCodeRegex: String {
    "^\\d{5}(?:[-\\s]\\d{4})?$"
  }

  public static var zipCode: Validator<T> {
    Validator { input -> ValidatorResult in
      guard
        let range = input.range(of: zipCodeRegex, options: [.regularExpression]),
        range.lowerBound == input.startIndex && range.upperBound == input.endIndex
      else {
        return ValidatorResults.ZipCode(isValidZipCode: false)
      }
      return ValidatorResults.ZipCode(isValidZipCode: true)
    }
  }
}
