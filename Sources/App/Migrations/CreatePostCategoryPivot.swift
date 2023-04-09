import Fluent

struct CreatePostCategoryPivot: Migration {
  func prepare(on database: Database) -> EventLoopFuture<Void> {
    database.schema("post-category-pivot")
      .id()
      .field("postID", .uuid, .required, .references("posts", "id", onDelete: .cascade))
      .field("categoryID", .uuid, .required, .references("categories", "id", onDelete: .cascade))
      .create()
  }
  
  func revert(on database: Database) -> EventLoopFuture<Void> {
    database.schema("post-category-pivot").delete()
  }
}
