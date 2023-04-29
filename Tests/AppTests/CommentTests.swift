@testable import App
import XCTVapor

final class CommentTests: XCTestCase {
    let commentsURI = "/api/comments/"
    let commentName = "Teenager"
    var app: Application!
    
    override func setUp() {
        app = try! Application.testable()
    }
    
    override func tearDown() {
        app.shutdown()
    }
    
    func testCommentsCanBeRetrievedFromAPI() throws {
        let comment = try Comment.create(name: commentName, on: app.db)
        _ = try Comment.create(on: app.db)
        
        try app.test(.GET, commentsURI, afterResponse: { response in
            let comments = try response.content.decode([App.Comment].self)
            XCTAssertEqual(comments.count, 2)
            XCTAssertEqual(comments[0].name, commentName)
            XCTAssertEqual(comments[0].id, comment.id)
        })
    }
    
    func testCommentCanBeSavedWithAPI() throws {
        let comment = Comment(name: commentName)
        
        try app.test(.POST, commentsURI, loggedInRequest: true, beforeRequest: { request in
            try request.content.encode(comment)
        }, afterResponse: { response in
            let receivedComment = try response.content.decode(Comment.self)
            XCTAssertEqual(receivedComment.name, commentName)
            XCTAssertNotNil(receivedComment.id)
            
            try app.test(.GET, commentsURI, afterResponse: { response in
                let comments = try response.content.decode([App.Comment].self)
                XCTAssertEqual(comments.count, 1)
                XCTAssertEqual(comments[0].name, commentName)
                XCTAssertEqual(comments[0].id, receivedComment.id)
            })
        })
    }
    
    func testGettingASingleCommentFromTheAPI() throws {
        let comment = try Comment.create(name: commentName, on: app.db)
        
        try app.test(.GET, "\(commentsURI)\(comment.id!)", afterResponse: { response in
            let returnedComment = try response.content.decode(Comment.self)
            XCTAssertEqual(returnedComment.name, commentName)
            XCTAssertEqual(returnedComment.id, comment.id)
        })
    }
    
    func testGettingACommentsPostsFromTheAPI() throws {
        let postTitle = "OMG"
        let postBody = "Oh My God"
        let post = try Post.create(title: postTitle, body: postBody, on: app.db)
        let post2 = try Post.create(on: app.db)
        
        let comment = try Comment.create(name: commentName, on: app.db)
        
        try app.test(.POST, "/api/posts/\(post.id!)/comments/\(comment.id!)", loggedInRequest: true)
        try app.test(.POST, "/api/posts/\(post2.id!)/comments/\(comment.id!)", loggedInRequest: true)
        
        try app.test(.GET, "\(commentsURI)\(comment.id!)/posts", afterResponse: { response in
            let posts = try response.content.decode([Post].self)
            XCTAssertEqual(posts.count, 2)
            XCTAssertEqual(posts[0].id, post.id)
            XCTAssertEqual(posts[0].title, postTitle)
            XCTAssertEqual(posts[0].body, postBody)
        })
    }
}
