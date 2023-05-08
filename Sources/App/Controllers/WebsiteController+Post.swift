//
//  WebsiteController+Post.swift
//  
//
//  Created by Alexander Sharko on 08.05.2023.
//

import Vapor
import Fluent
import SendGrid

extension WebsiteController {
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

struct CreatePostData: Content {
    let title: String
    let description: String
    let body: String
}
