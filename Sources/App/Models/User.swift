import Fluent
import Vapor

final class User: Model, Content {
    static let schema = "users"
    
    @ID
    var id: UUID?
    
    @Field(key: "username")
    var username: String
    
    @Field(key: "password")
    var password: String
    
    @Field(key: "email")
    var email: String
    
    @Children(for: \.$user)
    var posts: [Post]
    
    init() {}
    
    init(id: UUID? = nil, username: String, password: String, email: String) {
        self.username = username
        self.password = password
        self.email = email
    }
    
    final class Public: Content {
        var id: UUID?
        var username: String
        var email: String
        
        init(id: UUID?, username: String, email: String) {
            self.id = id
            self.username = username
            self.email = email
        }
    }
}

extension User {
    func convertToPublic() -> User.Public {
        return User.Public(id: id, username: username, email: email)
    }
}

extension EventLoopFuture where Value: User {
    func convertToPublic() -> EventLoopFuture<User.Public> {
        return self.map { user in
            return user.convertToPublic()
        }
    }
}

extension Collection where Element: User {
    func convertToPublic() -> [User.Public] {
        return self.map { $0.convertToPublic() }
    }
}

extension EventLoopFuture where Value == Array<User> {
    func convertToPublic() -> EventLoopFuture<[User.Public]> {
        return self.map { $0.convertToPublic() }
    }
}

extension User: ModelAuthenticatable {
    static let usernameKey = \User.$username
    static let passwordHashKey = \User.$password
    
    func verify(password: String) throws -> Bool {
        try Bcrypt.verify(password, created: self.password)
    }
}

extension User: ModelSessionAuthenticatable {}
extension User: ModelCredentialsAuthenticatable {}
