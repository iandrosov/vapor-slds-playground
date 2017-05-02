import Vapor
import HTTP
import Sessions


let memory = MemorySessions()
let sessions = SessionsMiddleware(sessions: memory)
let drop = Droplet()
drop.middleware.append(sessions)

// Home page
drop.get { request in
    return try drop.view.make("index.html")
}

// Render HTML
drop.get("home") { request in
    return try drop.view.make("welcome", [
        "message": drop.localization[request.lang, "welcome", "title"]
        ])

}

// Login via OAuth with SFDC
drop.get("login") { request in
    let sandboxURL = drop.config["sfdc", "oauth", "sandboxURL"]?.string ?? "https://test.salesforce.com"
    let developerURL = drop.config["sfdc", "oauth", "developerURL"]?.string ?? "https://login.salesforce.com"
    let url = drop.config["sfdc", "oauth", "redirectURL"]?.string ?? "default"
    let clientID = drop.config["sfdc", "oauth", "consumerKey"]?.string ?? "default"
    var base_url : String = developerURL
    if let instance = request.query?["instance"]?.string, instance == "sandbox" {
        base_url = sandboxURL
    }
    let params = [
        "response_type" : "code", // token
        "client_id" : clientID,
        "redirect_uri" : url,
        "prompt" : "login consent",
        "display" : "page" ] // touch
    print(params)
    let sfdcResponse = try drop.client.get("\(base_url)/services/oauth2/authorize", query:params)
    print(sfdcResponse)
    
    return sfdcResponse
}

// Response with auth session access token
drop.get("authorized") { request in
    
    let sandboxURL = drop.config["sfdc", "oauth", "sandboxURL"]?.string ?? "https://test.salesforce.com"
    let developerURL = drop.config["sfdc", "oauth", "developerURL"]?.string ?? "https://login.salesforce.com"
    var base_url : String = developerURL
    //if let instance = request.query?["instance"]?.string, instance == "sandbox" {
    //    base_url = sandboxURL
    //}
    
    print("REQ: \(request)")
    print("URI: \(request.uri)")
    print("PARM: \(request.parameters["code"])") //access_token
    print("BODY: \(request.body)")
    
    let scheme = request.uri.scheme // http
    let host = request.uri.host // vapor.codes
    print("HOST: \(scheme) : \(host)")
    let path = request.uri.path // /example
    let query = request.uri.query // query=hi
    print("URI: \(path):\(query)")
    
    guard let access_code = request.data["code"]?.string else {
        throw Abort.badRequest
    }
    print("Access code: \(access_code)")
    
    // POST Token request
    let url = drop.config["sfdc", "oauth", "redirectURL"]?.string ?? "default"
    let clientID = drop.config["sfdc", "oauth", "consumerKey"]?.string ?? "default"
    let clientSecret = drop.config["sfdc", "oauth", "consumerSecret"]?.string ?? "default"
    // Get Access token
    let sfdcResponse = try drop.client.post("\(base_url)/services/oauth2/token",
        headers: ["Content-Type": "application/x-www-form-urlencoded"],
        body: Body.data(Node(node: ["grant_type": "authorization_code",
                                    "client_id": clientID,
                                    "redirect_uri": url,
                                    "code": access_code,
                                    "client_secret": clientSecret ]).formURLEncoded()) )
    print(sfdcResponse)
    
    // Store token in session info
    //let access_token = sfdcResponse.body.bytes
    //let json = try JSON(bytes: access_token)
    //data["access_token"]?.string
    //try request.session().data["name"] = Node.string(name)
    
    if let bodyBytes = sfdcResponse.body.bytes {
        
        //let json_string = String(bytes: bodyBytes, encoding: String.Encoding.utf8)
        let json = try JSON(bytes: bodyBytes)
        //print(json)
        
        guard let access_token = json["access_token"]?.string else {
            throw Abort.badRequest
        }
        print("Access token: \(access_token)")
        try request.session().data["access_token"] = Node.string(access_token)
        
        guard let refresh_token = json["refresh_token"]?.string else {
            throw Abort.badRequest
        }
        print("Refresh token: \(refresh_token)")
        try request.session().data["refresh_token"] = Node.string(refresh_token)
        
        guard let instance_url = json["instance_url"]?.string else {
            throw Abort.badRequest
        }
        print("URL: \(instance_url)")
        try request.session().data["instance_url"] = Node.string(instance_url)
    }
    
    
    return sfdcResponse
}

drop.resource("posts", PostController())

drop.run()
