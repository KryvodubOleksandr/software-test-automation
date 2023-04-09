import Fluent

struct CreatePostCommentPivot: Migration {
  func prepare(on database: Database) -> EventLoopFuture<Void> {
    database.schema("post-comment-pivot")
      .id()
      .field("postID", .uuid, .required, .references("posts", "id", onDelete: .cascade))
      .field("commentID", .uuid, .required, .references("comments", "id", onDelete: .cascade))
      .create()
  }
  
  func revert(on database: Database) -> EventLoopFuture<Void> {
    database.schema("post-comment-pivot").delete()
  }
}
