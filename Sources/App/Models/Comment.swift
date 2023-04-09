import Fluent
import Vapor

final class Comment: Model, Content {
  static let schema = "comments"
  
  @ID
  var id: UUID?
  
  @Field(key: "name")
  var name: String
  
  @Siblings(through: PostCommentPivot.self, from: \.$comment, to: \.$post)
  var posts: [Post]
  
  init() {}
  
  init(id: UUID? = nil, name: String) {
    self.id = id
    self.name = name
  }
}

extension Comment {
  static func addComment(_ name: String, to post: Post, on req: Request) -> EventLoopFuture<Void> {
    Comment.query(on: req.db)
      .filter(\.$name == name)
      .first()
      .flatMap { foundComment in
        if let existingComment = foundComment {
          return post.$comments
            .attach(existingComment, on: req.db)
        } else {
          let comment = Comment(name: name)
          return comment.save(on: req.db).flatMap {
              post.$comments
              .attach(comment, on: req.db)
          }
        }
      }
  }
}
