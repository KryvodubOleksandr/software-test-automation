import Vapor
import Fluent

final class Post: Model {
    static let schema = "posts"
    
    @ID
    var id: UUID?
    
    @Field(key: "title")
    var title: String
    
    @Field(key: "description")
    var description: String
    
    @Field(key: "body")
    var body: String
    
    @Parent(key: "userID")
    var user: User
    
    @Children(for: \.$post)
    var comments: [Comment]
    
    init() {}
    
    init(id: UUID? = nil, title: String, description: String, body: String, userID: User.IDValue) {
        self.id = id
        self.title = title
        self.description = description
        self.body = body
        self.$user.id = userID
    }
}

extension Post: Content {}
