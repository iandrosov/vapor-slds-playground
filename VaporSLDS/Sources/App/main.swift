import Vapor

let drop = Droplet()

drop.get { req in
    return try drop.view.make("welcome", [
    	"message": drop.localization[req.lang, "welcome", "title"]
    ])
}

// Render HTML
drop.get("home") { request in
    return try drop.view.make("index.html")
}

drop.resource("posts", PostController())

drop.run()
