@testable import App
import XCTVapor

final class PostTests: XCTestCase {
  let postsURI = "/api/posts/"
  let postTitle = "OMG"
  let postLong = "Oh My God"
  var app: Application!

  override func setUp() {
    app = try! Application.testable()
  }

  override func tearDown() {
    app.shutdown()
  }

  func testPostsCanBeRetrievedFromAPI() throws {
    let post1 = try Post.create(title: postTitle, long: postLong, on: app.db)
    _ = try Post.create(on: app.db)

    try app.test(.GET, postsURI, afterResponse: { response in
      let posts = try response.content.decode([Post].self)
      XCTAssertEqual(posts.count, 2)
      XCTAssertEqual(posts[0].title, postTitle)
      XCTAssertEqual(posts[0].long, postLong)
      XCTAssertEqual(posts[0].id, post1.id)
    })
  }

  func testPostCanBeSavedWithAPI() throws {
    let user = try User.create(on: app.db)
    let createPostData = CreatePostData(title: postTitle, long: postLong)
    
    try app.test(.POST, postsURI, loggedInUser: user, beforeRequest: { request in
      try request.content.encode(createPostData)
    }, afterResponse: { response in
      let receivedPost = try response.content.decode(Post.self)
      XCTAssertEqual(receivedPost.title, postTitle)
      XCTAssertEqual(receivedPost.long, postLong)
      XCTAssertNotNil(receivedPost.id)
      XCTAssertEqual(receivedPost.$user.id, user.id)

      try app.test(.GET, postsURI, afterResponse: { allPostsResponse in
        let posts = try allPostsResponse.content.decode([Post].self)
        XCTAssertEqual(posts.count, 1)
        XCTAssertEqual(posts[0].title, postTitle)
        XCTAssertEqual(posts[0].long, postLong)
        XCTAssertEqual(posts[0].id, receivedPost.id)
        XCTAssertEqual(posts[0].$user.id, user.id)
      })
    })
  }

  func testGettingASinglePostFromTheAPI() throws {
    let post = try Post.create(title: postTitle, long: postLong, on: app.db)
    
    try app.test(.GET, "\(postsURI)\(post.id!)", afterResponse: { response in
      let returnedPost = try response.content.decode(Post.self)
      XCTAssertEqual(returnedPost.title, postTitle)
      XCTAssertEqual(returnedPost.long, postLong)
      XCTAssertEqual(returnedPost.id, post.id)
    })
  }

  func testUpdatingAnPost() throws {
    let post = try Post.create(title: postTitle, long: postLong, on: app.db)
    let newUser = try User.create(on: app.db)
    let newLong = "Oh My Gosh"
    let updatedPostData = CreatePostData(title: postTitle, long: newLong)
    
    try app.test(.PUT, "\(postsURI)\(post.id!)", loggedInUser: newUser, beforeRequest: { request in
      try request.content.encode(updatedPostData)
    })
    
    try app.test(.GET, "\(postsURI)\(post.id!)", afterResponse: { response in
      let returnedPost = try response.content.decode(Post.self)
      XCTAssertEqual(returnedPost.title, postTitle)
      XCTAssertEqual(returnedPost.long, newLong)
      XCTAssertEqual(returnedPost.$user.id, newUser.id)
    })
  }

  func testDeletingAnPost() throws {
    let post = try Post.create(on: app.db)
    
    try app.test(.GET, postsURI, afterResponse: { response in
      let posts = try response.content.decode([Post].self)
      XCTAssertEqual(posts.count, 1)
    })
    
    try app.test(.DELETE, "\(postsURI)\(post.id!)", loggedInRequest: true)
    
    try app.test(.GET, postsURI, afterResponse: { response in
      let newPosts = try response.content.decode([Post].self)
      XCTAssertEqual(newPosts.count, 0)
    })
  }

  func testSearchPostShort() throws {
    let post = try Post.create(title: postTitle, long: postLong, on: app.db)
    
    try app.test(.GET, "\(postsURI)search?term=OMG", afterResponse: { response in
      let posts = try response.content.decode([Post].self)
      XCTAssertEqual(posts.count, 1)
      XCTAssertEqual(posts[0].id, post.id)
      XCTAssertEqual(posts[0].title, postTitle)
      XCTAssertEqual(posts[0].long, postLong)
    })
  }

  func testSearchPostLong() throws {
    let post = try Post.create(title: postTitle, long: postLong, on: app.db)
    
    try app.test(.GET, "\(postsURI)search?term=Oh+My+God", afterResponse: { response in
      let posts = try response.content.decode([Post].self)
      XCTAssertEqual(posts.count, 1)
      XCTAssertEqual(posts[0].id, post.id)
      XCTAssertEqual(posts[0].title, postTitle)
      XCTAssertEqual(posts[0].long, postLong)
    })
  }

  func testGetFirstPost() throws {
    let post = try Post.create(title: postTitle, long: postLong, on: app.db)
    _ = try Post.create(on: app.db)
    _ = try Post.create(on: app.db)
    
    try app.test(.GET, "\(postsURI)first", afterResponse: { response in
      let firstPost = try response.content.decode(Post.self)
      XCTAssertEqual(firstPost.id, post.id)
      XCTAssertEqual(firstPost.title, postTitle)
      XCTAssertEqual(firstPost.long, postLong)
    })
  }

  func testSortingPosts() throws {
    let title2 = "LOL"
    let long2 = "Laugh Out Loud"
    let post1 = try Post.create(title: postTitle, long: postLong, on: app.db)
    let post2 = try Post.create(title: title2, long: long2, on: app.db)
    
    try app.test(.GET, "\(postsURI)sorted", afterResponse: { response in
      let sortedPosts = try response.content.decode([Post].self)
      XCTAssertEqual(sortedPosts[0].id, post2.id)
      XCTAssertEqual(sortedPosts[1].id, post1.id)
    })
  }

  func testGettingAnPostsUser() throws {
    let user = try User.create(on: app.db)
    let post = try Post.create(user: user, on: app.db)
    
    try app.test(.GET, "\(postsURI)\(post.id!)/user", afterResponse: { response in
      let postsUser = try response.content.decode(User.Public.self)
      XCTAssertEqual(postsUser.id, user.id)
      XCTAssertEqual(postsUser.name, user.name)
      XCTAssertEqual(postsUser.username, user.username)
    })
  }

  func testPostsCategories() throws {
    let category = try Category.create(on: app.db)
    let category2 = try Category.create(name: "Funny", on: app.db)
    let post = try Post.create(on: app.db)
    
    try app.test(.POST, "\(postsURI)\(post.id!)/categories/\(category.id!)", loggedInRequest: true)
    try app.test(.POST, "\(postsURI)\(post.id!)/categories/\(category2.id!)", loggedInRequest: true)
    
    try app.test(.GET, "\(postsURI)\(post.id!)/categories", afterResponse: { response in
      let categories = try response.content.decode([App.Category].self)
      XCTAssertEqual(categories.count, 2)
      XCTAssertEqual(categories[0].id, category.id)
      XCTAssertEqual(categories[0].name, category.name)
      XCTAssertEqual(categories[1].id, category2.id)
      XCTAssertEqual(categories[1].name, category2.name)
    })
    
    try app.test(.DELETE, "\(postsURI)\(post.id!)/categories/\(category.id!)", loggedInRequest: true)
    
    try app.test(.GET, "\(postsURI)\(post.id!)/categories", afterResponse: { response in
      let newCategories = try response.content.decode([App.Category].self)
      XCTAssertEqual(newCategories.count, 1)
    })
  }
}
