import Vapor

struct CategoriesController: RouteCollection {
  func boot(routes: RoutesBuilder) throws {
    let categoriesRoute = routes.grouped("api", "categories")
    categoriesRoute.get(use: getAllHandler)
    categoriesRoute.get(":categoryID", use: getHandler)
    categoriesRoute.get(":categoryID", "posts", use: getPostsHandler)

    let tokenAuthMiddleware = Token.authenticator()
    let guardAuthMiddleware = User.guardMiddleware()
    let tokenAuthGroup = categoriesRoute.grouped(tokenAuthMiddleware, guardAuthMiddleware)
    tokenAuthGroup.post(use: createHandler)
  }

  func createHandler(_ req: Request) throws -> EventLoopFuture<Category> {
    let category = try req.content.decode(Category.self)
    return category.save(on: req.db).map { category }
  }

  func getAllHandler(_ req: Request) -> EventLoopFuture<[Category]> {
    Category.query(on: req.db).all()
  }

  func getHandler(_ req: Request) -> EventLoopFuture<Category> {
    Category.find(req.parameters.get("categoryID"), on: req.db).unwrap(or: Abort(.notFound))
  }

  func getPostsHandler(_ req: Request) -> EventLoopFuture<[Post]> {
    Category.find(req.parameters.get("categoryID"), on: req.db)
      .unwrap(or: Abort(.notFound))
      .flatMap { category in
        category.$posts.get(on: req.db)
    }
  }
}
