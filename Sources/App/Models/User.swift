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
    
    @OptionalField(key: "firstname")
    var firstname: String?
    
    @OptionalField(key: "lastname")
    var lastname: String?
    
    @OptionalField(key: "age")
    var age: String?
    
    @OptionalField(key: "gender")
    var gender: String?
    
    @OptionalField(key: "address")
    var address: String?
    
    @OptionalField(key: "website")
    var website: String?
    
    @Children(for: \.$user)
    var posts: [Post]
    
    init() {}
    
    init(id: UUID? = nil,
         username: String,
         password: String,
         email: String,
         firstname: String? = nil,
         lastname: String? = nil,
         age: String? = nil,
         gender: String? = nil,
         address: String? = nil,
         website: String? = nil
    ) {
        self.username = username
        self.password = password
        self.email = email
        self.firstname = firstname
        self.lastname = lastname
        self.age = age
        self.gender = gender
        self.address = address
        self.website = website
    }
    
    final class Public: Content {
        var id: UUID?
        var username: String
        var email: String
        var firstname: String?
        var lastname: String?
        var age: String?
        var gender: String?
        var address: String?
        var website: String?
        
        init(
            id: UUID?,
            username: String,
            email: String,
            firstname: String? = nil,
            lastname: String? = nil,
            age: String? = nil,
            gender: String? = nil,
            address: String? = nil,
            website: String? = nil
        ) {
            self.id = id
            self.username = username
            self.email = email
            self.firstname = firstname
            self.lastname = lastname
            self.age = age
            self.gender = gender
            self.address = address
            self.website = website
        }
    }
}

extension User {
    func convertToPublic() -> User.Public {
        return User.Public(
            id: id,
            username: username,
            email: email,
            firstname: firstname,
            lastname: lastname,
            age: age,
            gender: gender,
            address: address,
            website: website
        )
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
