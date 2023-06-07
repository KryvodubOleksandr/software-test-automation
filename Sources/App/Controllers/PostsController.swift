//
//  PostsController.swift
//  
//
//  Created by Alexander Sharko on 07.06.2023.
//

import Vapor
import Fluent
import SendGrid

struct PostsController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let postsRoutes = routes.grouped("api", "posts")
        postsRoutes.get(use: getAllHandler)
        postsRoutes.get(":postID", use: getHandler)
        postsRoutes.get(":postID", "user", use: getUserHandler)
        postsRoutes.get(":postID", "comments", use: getCommentsHandler)
        
        let tokenAuthMiddleware = Token.authenticator()
        let guardAuthMiddleware = User.guardMiddleware()
        let tokenAuthGroup = postsRoutes.grouped(tokenAuthMiddleware, guardAuthMiddleware)
        tokenAuthGroup.post(use: createHandler)
        tokenAuthGroup.post("comments", use: addCommentHandler)
    }
    
    func getAllHandler(_ req: Request) -> EventLoopFuture<[Post]> {
        Post.query(on: req.db).all()
    }
    
    func createHandler(_ req: Request) throws -> EventLoopFuture<Post> {
        let data = try req.content.decode(CreatePostData.self)
        let user = try req.auth.require(User.self)
        let post = try Post(title: data.title, description: data.description, body: data.body, userID: user.requireID())
        return post.save(on: req.db).map { post }
    }
    
    func getHandler(_ req: Request) -> EventLoopFuture<Post> {
        Post.find(req.parameters.get("postID"), on: req.db)
            .unwrap(or: Abort(.notFound))
    }
    
    func getUserHandler(_ req: Request) -> EventLoopFuture<User.Public> {
        Post.find(req.parameters.get("postID"), on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { post in
                post.$user.get(on: req.db).convertToPublic()
            }
    }
    
    func addCommentHandler(_ req: Request) throws -> EventLoopFuture<Comment> {
        let data = try req.content.decode(CreateCommentFormData.self)
        let user = try req.auth.require(User.self)
        let comment = Comment(name: data.name, message: data.message, postID: data.postId)
        return comment.save(on: req.db).map { comment }
    }
    
    func getCommentsHandler(_ req: Request) -> EventLoopFuture<[Comment]> {
        Post.find(req.parameters.get("postID"), on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { post in
                post.$comments.query(on: req.db).all()
            }
    }
}
