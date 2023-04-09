import Vapor
import Fluent

final class Post: Model {
  static let schema = "posts"
  
  @ID
  var id: UUID?
  
  @Field(key: "title")
  var title: String
  
  @Field(key: "long")
  var long: String
  
  @Parent(key: "userID")
  var user: User
  
  @Siblings(through: PostCategoryPivot.self, from: \.$post, to: \.$category)
  var categories: [Category]
  
  init() {}
  
  init(id: UUID? = nil, title: String, long: String, userID: User.IDValue) {
    self.id = id
    self.title = title
    self.long = long
    self.$user.id = userID
  }
}

extension Post: Content {}
