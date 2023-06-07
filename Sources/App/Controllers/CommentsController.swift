//
//  CommentsController.swift
//  
//
//  Created by Alexander Sharko on 07.06.2023.
//

import Vapor

struct CommentsController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let commentsRoute = routes.grouped("api", "comments")
        commentsRoute.get(use: getAllHandler)
        commentsRoute.get(":commentID", use: getHandler)
    }
    
    func getAllHandler(_ req: Request) -> EventLoopFuture<[Comment]> {
        Comment.query(on: req.db).all()
    }
    
    func getHandler(_ req: Request) -> EventLoopFuture<Comment> {
        Comment.find(req.parameters.get("commentID"), on: req.db).unwrap(or: Abort(.notFound))
    }
}
