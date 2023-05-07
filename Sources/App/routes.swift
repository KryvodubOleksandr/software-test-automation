import Fluent
import Vapor

func routes(_ app: Application) throws {  
    app.get("hello") { req -> String in
        return "Hello, world!"
    }
    
    let websiteController = WebsiteController()
    try app.register(collection: websiteController)
}
