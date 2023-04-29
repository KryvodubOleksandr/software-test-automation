import Fluent
import Foundation

final class PostCommentPivot: Model {
    static let schema = "post-comment-pivot"
    
    @ID
    var id: UUID?
    
    @Parent(key: "postID")
    var post: Post
    
    @Parent(key: "commentID")
    var comment: Comment
    
    init() {}
    
    init(id: UUID? = nil, post: Post, comment: Comment) throws {
        self.id = id
        self.$post.id = try post.requireID()
        self.$comment.id = try comment.requireID()
    }
}
