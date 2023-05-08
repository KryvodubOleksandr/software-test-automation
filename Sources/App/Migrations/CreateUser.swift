import Fluent

struct CreateUser: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("users")
            .id()
            .field("username", .string, .required)
            .field("email", .string, .required)
            .field("password", .string, .required)
            .field("firstname", .string)
            .field("lastname", .string)
            .field("age", .string)
            .field("gender", .string)
            .field("address", .string)
            .field("website", .string)
            .unique(on: "username")
            .unique(on: "email")
            .create()
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("users").delete()
    }
}
