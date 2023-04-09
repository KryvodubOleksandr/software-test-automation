@testable import App
import XCTVapor

final class CategoryTests: XCTestCase {
  let categoriesURI = "/api/categories/"
  let categoryName = "Teenager"
  var app: Application!

  override func setUp() {
    app = try! Application.testable()
  }

  override func tearDown() {
    app.shutdown()
  }

  func testCategoriesCanBeRetrievedFromAPI() throws {
    let category = try Category.create(name: categoryName, on: app.db)
    _ = try Category.create(on: app.db)
    
    try app.test(.GET, categoriesURI, afterResponse: { response in
      let categories = try response.content.decode([App.Category].self)
      XCTAssertEqual(categories.count, 2)
      XCTAssertEqual(categories[0].name, categoryName)
      XCTAssertEqual(categories[0].id, category.id)
    })
  }

  func testCategoryCanBeSavedWithAPI() throws {
    let category = Category(name: categoryName)
    
    try app.test(.POST, categoriesURI, loggedInRequest: true, beforeRequest: { request in
      try request.content.encode(category)
    }, afterResponse: { response in
      let receivedCategory = try response.content.decode(Category.self)
      XCTAssertEqual(receivedCategory.name, categoryName)
      XCTAssertNotNil(receivedCategory.id)

      try app.test(.GET, categoriesURI, afterResponse: { response in
        let categories = try response.content.decode([App.Category].self)
        XCTAssertEqual(categories.count, 1)
        XCTAssertEqual(categories[0].name, categoryName)
        XCTAssertEqual(categories[0].id, receivedCategory.id)
      })
    })
  }

  func testGettingASingleCategoryFromTheAPI() throws {
    let category = try Category.create(name: categoryName, on: app.db)
    
    try app.test(.GET, "\(categoriesURI)\(category.id!)", afterResponse: { response in
      let returnedCategory = try response.content.decode(Category.self)
      XCTAssertEqual(returnedCategory.name, categoryName)
      XCTAssertEqual(returnedCategory.id, category.id)
    })
  }

  func testGettingACategoriesPostsFromTheAPI() throws {
    let postTitle = "OMG"
    let postDescription = "Oh My God"
    let post = try Post.create(title: postTitle, long: postDescription, on: app.db)
    let post2 = try Post.create(on: app.db)

    let category = try Category.create(name: categoryName, on: app.db)
    
    try app.test(.POST, "/api/posts/\(post.id!)/categories/\(category.id!)", loggedInRequest: true)
    try app.test(.POST, "/api/posts/\(post2.id!)/categories/\(category.id!)", loggedInRequest: true)

    try app.test(.GET, "\(categoriesURI)\(category.id!)/posts", afterResponse: { response in
      let posts = try response.content.decode([Post].self)
      XCTAssertEqual(posts.count, 2)
      XCTAssertEqual(posts[0].id, post.id)
      XCTAssertEqual(posts[0].title, postTitle)
      XCTAssertEqual(posts[0].long, postDescription)
    })
  }
}
