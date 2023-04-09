import Fluent
import Vapor

func routes(_ app: Application) throws {  
  app.get("hello") { req -> String in
    return "Hello, world!"
  }
  
  let postsController = PostsController()
  try app.register(collection: postsController)
  
  let usersController = UsersController()
  try app.register(collection: usersController)
  
  let commentsController = CommentsController()
  try app.register(collection: commentsController)

  let websiteController = WebsiteController()
  try app.register(collection: websiteController)
}
