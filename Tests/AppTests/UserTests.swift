@testable import App
import XCTVapor

final class UserTests: XCTestCase {
  let usersName = "Alice"
  let usersUsername = "alicea"
  let usersURI = "/api/users/"
  var app: Application!
  
  override func setUpWithError() throws {
    app = try Application.testable()
  }
  
  override func tearDownWithError() throws {
    app.shutdown()
  }
  
  func testUsersCanBeRetrievedFromAPI() throws {
    let user = try User.create(name: usersName, username: usersUsername, on: app.db)
    _ = try User.create(on: app.db)

    try app.test(.GET, usersURI, afterResponse: { response in
      
      XCTAssertEqual(response.status, .ok)
      let users = try response.content.decode([User.Public].self)
      
      XCTAssertEqual(users.count, 3)
      XCTAssertEqual(users[1].name, usersName)
      XCTAssertEqual(users[1].username, usersUsername)
      XCTAssertEqual(users[1].id, user.id)
    })
  }
  
  func testUserCanBeSavedWithAPI() throws {
    let user = User(name: usersName, username: usersUsername, password: "password")

    try app.test(.POST, usersURI, loggedInRequest: true, beforeRequest: { req in
      try req.content.encode(user)
    }, afterResponse: { response in
      let receivedUser = try response.content.decode(User.Public.self)
      XCTAssertEqual(receivedUser.name, usersName)
      XCTAssertEqual(receivedUser.username, usersUsername)
      XCTAssertNotNil(receivedUser.id)

      try app.test(.GET, usersURI, afterResponse: { secondResponse in
        let users = try secondResponse.content.decode([User.Public].self)
        XCTAssertEqual(users.count, 2)
        XCTAssertEqual(users[1].name, usersName)
        XCTAssertEqual(users[1].username, usersUsername)
        XCTAssertEqual(users[1].id, receivedUser.id)
      })
    })
  }
  
  func testGettingASingleUserFromTheAPI() throws {
    let user = try User.create(name: usersName, username: usersUsername, on: app.db)
    
    try app.test(.GET, "\(usersURI)\(user.id!)", afterResponse: { response in
      let receivedUser = try response.content.decode(User.Public.self)
      XCTAssertEqual(receivedUser.name, usersName)
      XCTAssertEqual(receivedUser.username, usersUsername)
      XCTAssertEqual(receivedUser.id, user.id)
    })
  }
  
  func testGettingAUsersPostsFromTheAPI() throws {
    let user = try User.create(on: app.db)

    let postTitle = "OMG"
    let postDescription = "Oh My God"
    
    let post1 = try Post.create(title: postTitle, long: postDescription, user: user, on: app.db)
    _ = try Post.create(title: "LOL", long: "Laugh Out Loud", user: user, on: app.db)

    try app.test(.GET, "\(usersURI)\(user.id!)/posts", afterResponse: { response in
      let posts = try response.content.decode([Post].self)
      XCTAssertEqual(posts.count, 2)
      XCTAssertEqual(posts[0].id, post1.id)
      XCTAssertEqual(posts[0].title, postTitle)
      XCTAssertEqual(posts[0].long, postDescription)
    })
  }
}
