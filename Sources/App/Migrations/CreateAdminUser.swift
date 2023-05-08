import Fluent
import Vapor

struct CreateAdminUser: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        let passwordHash: String
        do {
            passwordHash = try Bcrypt.hash("password")
        } catch {
            return database.eventLoop.future(error: error)
        }
        let user = User(
            username: "admin",
            password: passwordHash,
            email: "admin@localhost.local",
            firstname: "firstname",
            lastname: "lastname",
            age: "25",
            gender: "gender",
            address: "address",
            website: "website"
        )
        return user.save(on: database)
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        User.query(on: database).filter(\.$username == "admin").delete()
    }
}
