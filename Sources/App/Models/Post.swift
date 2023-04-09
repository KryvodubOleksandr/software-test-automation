import Vapor
import Fluent

final class Post: Model {
  static let schema = "posts"
  
  @ID
  var id: UUID?
  
  @Field(key: "title")
  var title: String
  
  @Field(key: "body")
  var body: String
  
  @Parent(key: "userID")
  var user: User
  
  @Siblings(through: PostCommentPivot.self, from: \.$post, to: \.$comment)
  var comments: [Comment]
  
  init() {}
  
  init(id: UUID? = nil, title: String, body: String, userID: User.IDValue) {
    self.id = id
    self.title = title
    self.body = body
    self.$user.id = userID
  }
}

extension Post: Content {}
