import Vapor

let drop = Droplet()

drop.get { request in
    return try drop.view.make("index.html")
}

// Render HTML
drop.get("home") { request in
    return try drop.view.make("welcome", [
        "message": drop.localization[request.lang, "welcome", "title"]
        ])

}

drop.resource("posts", PostController())

drop.run()
