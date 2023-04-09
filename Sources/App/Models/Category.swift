import Fluent
import Vapor

final class Category: Model, Content {
  static let schema = "categories"
  
  @ID
  var id: UUID?
  
  @Field(key: "name")
  var name: String
  
  @Siblings(through: PostCategoryPivot.self, from: \.$category, to: \.$post)
  var posts: [Post]
  
  init() {}
  
  init(id: UUID? = nil, name: String) {
    self.id = id
    self.name = name
  }
}

extension Category {
  static func addCategory(_ name: String, to post: Post, on req: Request) -> EventLoopFuture<Void> {
    Category.query(on: req.db)
      .filter(\.$name == name)
      .first()
      .flatMap { foundCategory in
        if let existingCategory = foundCategory {
          return post.$categories
            .attach(existingCategory, on: req.db)
        } else {
          let category = Category(name: name)
          return category.save(on: req.db).flatMap {
              post.$categories
              .attach(category, on: req.db)
          }
        }
      }
  }
}
