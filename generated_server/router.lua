local router = {}

function router.route(method, path, request)
    local endpoint = router[method .. " " .. path]
    if endpoint then
        return endpoint.handler(request)
    else
        return { status = 404, body = "Not Found" }
    end
end
router["GET /user/{id}"] = { handler = require("handlers.getUser") }
router["POST /user"] = { handler = require("handlers.createUser") }

return router