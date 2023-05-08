@testable import App
import Fluent
import Vapor

extension User {
    // 1
    static func create(
        username: String? = nil,
        on database: Database
    ) throws -> User {
        let createUsername: String
        // 2
        if let suppliedUsername = username {
            createUsername = suppliedUsername
            // 3
        } else {
            createUsername = UUID().uuidString
        }
        
        // 4
        let password = try Bcrypt.hash("password")
        let user = User(
            username: createUsername,
            password: password,
            email: "\(createUsername)@mail.com",
            firstname: "Oleksandr",
            lastname: "Kryvodub",
            age: "33",
            gender: "male",
            address: "Ukraine",
            website: "github.com"
        )
        try user.save(on: database).wait()
        return user
    }
}

extension Post {
    static func create(
        title: String = "title",
        description: String = "description",
        body: String = "body",
        user: User? = nil,
        on database: Database
    ) throws -> Post {
        var postsUser = user
        
        if postsUser == nil {
            postsUser = try User.create(on: database)
        }
        
        let post = Post(
            title: title,
            description: description,
            body: body,
            userID: postsUser!.id!)
        try post.save(on: database).wait()
        return post
    }
}

extension App.Comment {
    static func create(
        name: String = "Random",
        message: String = "Text message",
        on database: Database
    ) throws -> App.Comment {
        let comment = Comment(name: name, message: message, postID: UUID())
        try comment.save(on: database).wait()
        return comment
    }
}
