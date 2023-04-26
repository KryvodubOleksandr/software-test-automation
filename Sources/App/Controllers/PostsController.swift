import Vapor
import Fluent
//
//struct PostsController: RouteCollection {
//    func boot(routes: RoutesBuilder) throws {
//        let postsRoutes = routes.grouped("api", "posts")
//        postsRoutes.get(use: getAllHandler)
//        postsRoutes.get(":postID", use: getHandler)
//        postsRoutes.get("search", use: searchHandler)
//        postsRoutes.get("first", use: getFirstHandler)
//        postsRoutes.get("sorted", use: sortedHandler)
//        postsRoutes.get(":postID", "user", use: getUserHandler)
//        postsRoutes.get(":postID", "comments", use: getCommentsHandler)
//        
//        let tokenAuthMiddleware = Token.authenticator()
//        let guardAuthMiddleware = User.guardMiddleware()
//        let tokenAuthGroup = postsRoutes.grouped(tokenAuthMiddleware, guardAuthMiddleware)
//        tokenAuthGroup.post(use: createHandler)
//        tokenAuthGroup.delete(":postID", use: deleteHandler)
//        tokenAuthGroup.put(":postID", use: updateHandler)
//        tokenAuthGroup.post(":postID", "comments", ":commentID", use: addCommentsHandler)
//        tokenAuthGroup.delete(":postID", "comments", ":commentID", use: removeCommentsHandler)
//    }
//    
//    func getAllHandler(_ req: Request) -> EventLoopFuture<[Post]> {
//        Post.query(on: req.db).all()
//    }
//    
//    func createHandler(_ req: Request) throws -> EventLoopFuture<Post> {
//        let data = try req.content.decode(CreatePostData.self)
//        let user = try req.auth.require(User.self)
//        let post = try Post(title: data.title, description: data.description, body: data.body, userID: user.requireID())
//        return post.save(on: req.db).map { post }
//    }
//    
//    func getHandler(_ req: Request) -> EventLoopFuture<Post> {
//        Post.find(req.parameters.get("postID"), on: req.db)
//            .unwrap(or: Abort(.notFound))
//    }
//    
//    func updateHandler(_ req: Request) throws -> EventLoopFuture<Post> {
//        let updateData = try req.content.decode(CreatePostData.self)
//        let user = try req.auth.require(User.self)
//        let userID = try user.requireID()
//        return Post.find(req.parameters.get("postID"), on: req.db)
//            .unwrap(or: Abort(.notFound)).flatMap { post in
//                post.title = updateData.title
//                post.body = updateData.body
//                post.$user.id = userID
//                return post.save(on: req.db).map {
//                    post
//                }
//            }
//    }
//    
//    func deleteHandler(_ req: Request)
//    -> EventLoopFuture<HTTPStatus> {
//        Post.find(req.parameters.get("postID"), on: req.db)
//            .unwrap(or: Abort(.notFound))
//            .flatMap { post in
//                post.delete(on: req.db)
//                    .transform(to: .noContent)
//            }
//    }
//    
//    func searchHandler(_ req: Request) throws -> EventLoopFuture<[Post]> {
//        guard let searchTerm = req
//            .query[String.self, at: "term"] else {
//            throw Abort(.badRequest)
//        }
//        return Post.query(on: req.db).group(.or) { or in
//            or.filter(\.$title == searchTerm)
//            or.filter(\.$body == searchTerm)
//        }.all()
//    }
//    
//    func getFirstHandler(_ req: Request) -> EventLoopFuture<Post> {
//        return Post.query(on: req.db)
//            .first()
//            .unwrap(or: Abort(.notFound))
//    }
//    
//    func sortedHandler(_ req: Request) -> EventLoopFuture<[Post]> {
//        return Post.query(on: req.db).sort(\.$title, .ascending).all()
//    }
//    
//    func getUserHandler(_ req: Request) -> EventLoopFuture<User.Public> {
//        Post.find(req.parameters.get("postID"), on: req.db)
//            .unwrap(or: Abort(.notFound))
//            .flatMap { post in
//                post.$user.get(on: req.db).convertToPublic()
//            }
//    }
//    
//    func addCommentsHandler(_ req: Request) -> EventLoopFuture<HTTPStatus> {
//        let postQuery = Post.find(req.parameters.get("postID"), on: req.db).unwrap(or: Abort(.notFound))
//        let commentQuery = Comment.find(req.parameters.get("postID"), on: req.db).unwrap(or: Abort(.notFound))
//        return postQuery.and(commentQuery).flatMap { post, comment in
//            post.$comments.attach(comment, on: req.db).transform(to: .created)
//        }
//    }
//    
//    func getCommentsHandler(_ req: Request) -> EventLoopFuture<[Comment]> {
//        Post.find(req.parameters.get("postID"), on: req.db)
//            .unwrap(or: Abort(.notFound))
//            .flatMap { post in
//                post.$comments.query(on: req.db).all()
//            }
//    }
//    
//    func removeCommentsHandler(_ req: Request) -> EventLoopFuture<HTTPStatus> {
//        let postQuery = Post.find(req.parameters.get("postID"), on: req.db).unwrap(or: Abort(.notFound))
//        let commentQuery = Comment.find(req.parameters.get("postID"), on: req.db).unwrap(or: Abort(.notFound))
//        return postQuery.and(commentQuery).flatMap { post, comment in
//            post.$comments.detach(comment, on: req.db).transform(to: .noContent)
//        }
//    }
//}

struct CreatePostData: Content {
    let title: String
    let description: String
    let body: String
}
