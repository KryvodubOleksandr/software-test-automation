//import Vapor
//
//struct CommentsController: RouteCollection {
//    func boot(routes: RoutesBuilder) throws {
//        let commentsRoute = routes.grouped("api", "comments")
//        commentsRoute.get(use: getAllHandler)
//        commentsRoute.get(":commentID", use: getHandler)
//        commentsRoute.get(":commentID", "posts", use: getPostsHandler)
//        
//        let tokenAuthMiddleware = Token.authenticator()
//        let guardAuthMiddleware = User.guardMiddleware()
//        let tokenAuthGroup = commentsRoute.grouped(tokenAuthMiddleware, guardAuthMiddleware)
//        tokenAuthGroup.post(use: createHandler)
//    }
//    
//    func createHandler(_ req: Request) throws -> EventLoopFuture<Comment> {
//        let comment = try req.content.decode(Comment.self)
//        return comment.save(on: req.db).map { comment }
//    }
//    
//    func getAllHandler(_ req: Request) -> EventLoopFuture<[Comment]> {
//        Comment.query(on: req.db).all()
//    }
//    
//    func getHandler(_ req: Request) -> EventLoopFuture<Comment> {
//        Comment.find(req.parameters.get("commentID"), on: req.db).unwrap(or: Abort(.notFound))
//    }
//    
//    func getPostsHandler(_ req: Request) -> EventLoopFuture<[Post]> {
//        Comment.find(req.parameters.get("commentID"), on: req.db)
//            .unwrap(or: Abort(.notFound))
//            .flatMap { comment in
//                comment.$posts.get(on: req.db)
//            }
//    }
//}
