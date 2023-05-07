import Fluent
import Vapor

final class Comment: Model, Content {
    static let schema = "comments"
    
    @ID
    var id: UUID?
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "message")
    var message: String
    
    @Parent(key: "postID")
    var post: Post
    
    init() {}
    
    init(id: UUID? = nil, name: String, message: String, postID: Post.IDValue) {
        self.id = id
        self.name = name
        self.message = message
        self.$post.id = postID
    }
}
