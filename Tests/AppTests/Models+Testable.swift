@testable import App
import Fluent
import Vapor

extension User {
  // 1
  static func create(
    name: String = "Luke",
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
      name: name,
      username: createUsername,
      password: password)
    try user.save(on: database).wait()
    return user
  }
}

extension Post {
  static func create(
    title: String = "TIL",
    body: String = "Today I Learned",
    user: User? = nil,
    on database: Database
  ) throws -> Post {
    var postsUser = user
    
    if postsUser == nil {
      postsUser = try User.create(on: database)
    }
    
    let post = Post(
      title: title,
      body: body,
      userID: postsUser!.id!)
    try post.save(on: database).wait()
    return post
  }
}

extension App.Comment {
  static func create(
    name: String = "Random",
    on database: Database
  ) throws -> App.Comment {
    let comment = Comment(name: name)
    try comment.save(on: database).wait()
    return comment
  }
}
