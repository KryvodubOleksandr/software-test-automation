//import Vapor
//import JWT
//import Fluent
//
//struct UsersController: RouteCollection {
//    func boot(routes: RoutesBuilder) throws {
//        let usersRoute = routes.grouped("api", "users")
//        usersRoute.get(":userID", use: getHandler)
//        usersRoute.get(":userID", "posts", use: getPostsHandler)
//        let basicAuthMiddleware = User.authenticator()
//        let basicAuthGroup = usersRoute.grouped(basicAuthMiddleware)
//        basicAuthGroup.post("login", use: loginHandler)
//        
//        let tokenAuthMiddleware = Token.authenticator()
//        let guardAuthMiddleware = User.guardMiddleware()
//        let tokenAuthGroup = usersRoute.grouped(tokenAuthMiddleware, guardAuthMiddleware)
//        tokenAuthGroup.post(use: createHandler)
//    }
//    
//    func createHandler(_ req: Request) throws -> EventLoopFuture<User.Public> {
//        let user = try req.content.decode(User.self)
//        user.password = try Bcrypt.hash(user.password)
//        return user.save(on: req.db).map { user.convertToPublic() }
//    }
//    
//    func getHandler(_ req: Request) -> EventLoopFuture<User.Public> {
//        User.find(req.parameters.get("userID"), on: req.db).unwrap(or: Abort(.notFound)).convertToPublic()
//    }
//    
//    func getPostsHandler(_ req: Request) -> EventLoopFuture<[Post]> {
//        User.find(req.parameters.get("userID"), on: req.db).unwrap(or: Abort(.notFound)).flatMap { user in
//            user.$posts.get(on: req.db)
//        }
//    }
//    
//    func loginHandler(_ req: Request) throws -> EventLoopFuture<Token> {
//        let user = try req.auth.require(User.self)
//        let token = try Token.generate(for: user)
//        return token.save(on: req.db).map { token }
//    }
//}
