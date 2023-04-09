import Fluent

struct CreatePost: Migration {
  func prepare(on database: Database) -> EventLoopFuture<Void> {
    database.schema("posts")
      .id()
      .field("title", .string, .required)
      .field("long", .string, .required)
      .field("userID", .uuid, .required, .references("users", "id"))
      .create()
  }
  
  func revert(on database: Database) -> EventLoopFuture<Void> {
    database.schema("posts").delete()
  }
}
