import Fluent

struct CreateComment: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("comments")
            .id()
            .field("name", .string, .required)
            .field("message", .string, .required)
            .field("postID", .uuid, .required, .references("posts", "id"))
            .create()
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("comments").delete()
    }
}
