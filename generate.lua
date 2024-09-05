-- Server Code Generator cải tiến từ schema đã xử lý
local processor = require("processor")

-- Đảm bảo tất cả các hàm sử dụng đều được khai báo cục bộ
local parse_schema = processor.parse_schema
local lua_code = processor.lua_code

-- Hàm tạo thư mục nếu chưa tồn tại
local function create_directory_if_needed(directory)
    local is_windows = package.config:sub(1, 1) == "\\"
    local mkdir_command = is_windows and ("mkdir " .. directory) or ("mkdir -p " .. directory)
    os.execute(mkdir_command)
end

-- Hàm lưu nội dung vào file
local function save_to_file(filename, content)
    if not filename or type(filename) ~= "string" then
        error("Invalid filename")
    end
    if not content or type(content) ~= "string" then
        error("Invalid content")
    end

    local directory = filename:match("(.*/)")
    if directory then
        create_directory_if_needed(directory)
    end

    local file, err = io.open(filename, "w")
    if not file then
        error("Could not open file for writing: " .. err)
    end

    file:write(content)
    file:close()
end

-- Sinh mã cho router
local function generate_router(schema)
    local router_code = [[
local router = {}

function router.route(method, path, request)
    local endpoint = router[method .. " " .. path]
    if endpoint then
        return endpoint.handler(request)
    else
        return { status = 404, body = "Not Found" }
    end
end
]]
    for _, endpoint in ipairs(schema.endpoints) do
        local route_key = endpoint.method .. " " .. endpoint.path
        router_code = router_code .. string.format('router["%s"] = { handler = require("handlers.%s") }\n', route_key, endpoint.name)
    end
    return router_code .. "\nreturn router"
end

-- Sinh mã cho middlewares chỉ khi cần thiết
local function generate_middleware_code(endpoint)
    local middleware_code = {}

    if endpoint.middlewares then
        for _, mw in ipairs(endpoint.middlewares) do
            if mw == "auth" then
                table.insert(middleware_code, [[
    -- Middleware xác thực
    local auth_result = middlewares.auth(request)
    if auth_result then return auth_result end
]])
            elseif mw == "logging" then
                table.insert(middleware_code, string.format([[
    -- Middleware ghi log
    middlewares.logging("%s")
]], endpoint.name))
            elseif mw == "rate_limiter" then
                table.insert(middleware_code, [[
    -- Middleware giới hạn tốc độ
    local rate_limiter_result = middlewares.rate_limiter(request)
    if rate_limiter_result then return rate_limiter_result end
]])
            end
        end
    end

    return table.concat(middleware_code, "\n")
end

-- Sinh mã cho các params cần validation
local function generate_validation_params(params)
    local params_code = {}

    for _, param in ipairs(params) do
        table.insert(params_code, string.format('        { name = "%s", type = "%s", required = %s }',
            param.name, param.type, param.required and "true" or "false"))
    end

    return "{\n" .. table.concat(params_code, ",\n") .. "\n    }"
end

-- Sinh mã kiểm tra đầu vào (params) chỉ khi cần thiết
local function generate_validation_code(endpoint)
    local validation_code = {}

    if endpoint.params and #endpoint.params > 0 then
        table.insert(validation_code, string.format([[
    -- Kiểm tra params
    local validation_result = validation.params(%s, request.body)
    if validation_result then return validation_result end
]], generate_validation_params(endpoint.params)))
    end

    return table.concat(validation_code, "\n")
end

-- Sinh mã phản hồi chỉ khi có định nghĩa responses
local function generate_response_code(endpoint)
    local response_code = {}

    if endpoint.responses then
        -- Xử lý phản hồi thành công
        if endpoint.responses.success then
            table.insert(response_code, [[
    -- Phản hồi thành công
    local response_data = { id = request.body.id, name = request.body.name, email = request.body.email }
    return responses.success(response_data)
]])
        end

        -- Xử lý lỗi client (bad request)
        if endpoint.responses.bad_request then
            table.insert(response_code, [[
    -- Phản hồi lỗi yêu cầu không hợp lệ
    -- Chỉ cung cấp thông tin lỗi chung chung
    if not request.body.name or not request.body.email then
        return responses.bad_request("Invalid input")
    end
]])
        end

        -- Xử lý lỗi server
        if endpoint.responses.server_error then
            table.insert(response_code, [[
    -- Phản hồi lỗi server
    local internal_error = false -- Điều kiện cụ thể sẽ được áp dụng
    if internal_error then
        return responses.server_error("An internal error occurred")
    end
]])
        end
    else
        -- Trả về phản hồi mặc định khi không có response
        table.insert(response_code, [[
    -- Phản hồi mặc định
    return responses.success({ message = "Request completed successfully" })
]])
    end

    return table.concat(response_code, "\n")
end


-- Sinh logic mặc định cho mỗi endpoint
local function generate_logic_code(endpoint)
    return [[
-- Logic chính của endpoint
local response_body = { message = "Endpoint logic chưa được triển khai" }
]]
end

-- Sinh mã cho handler, chỉ thêm require khi cần thiết
local function generate_handler_code(endpoint)
    local requires = {}
    local handler_body = {}

    -- Chỉ thêm require cho middlewares nếu có sử dụng
    if endpoint.middlewares and #endpoint.middlewares > 0 then
        table.insert(requires, 'local middlewares = require("middlewares")')
        table.insert(handler_body, generate_middleware_code(endpoint))
    end

    -- Chỉ thêm require cho validation nếu có params cần kiểm tra
    if endpoint.params and #endpoint.params > 0 then
        table.insert(requires, 'local validation = require("validation")')
        table.insert(handler_body, generate_validation_code(endpoint))
    end

    -- Chỉ thêm require cho responses nếu có định nghĩa responses
    if endpoint.responses then
        table.insert(requires, 'local responses = require("responses")')
        table.insert(handler_body, generate_response_code(endpoint))
    end

    -- Sinh logic chính của endpoint
    table.insert(handler_body, generate_logic_code(endpoint))

    -- Kết hợp các phần thành mã hoàn chỉnh cho handler
    local handler_code = string.format([[
-- Handler cho endpoint: %s
%s

local function %s(request)
%s
end

return %s
]], endpoint.name, table.concat(requires, "\n"), endpoint.name, table.concat(handler_body, "\n"), endpoint.name)

    return handler_code
end

-- Hàm chính để sinh mã server
local function generate_server_code(schema)
    -- Sinh router
    local router_code = generate_router(schema)
    save_to_file("generated_server/router.lua", router_code)

    -- Sinh handlers cho từng endpoint
    for _, endpoint in ipairs(schema.endpoints) do
        local handler_code = generate_handler_code(endpoint)
        save_to_file(string.format("generated_server/handlers/%s.lua", endpoint.name), handler_code)
    end
end

-- Thực thi sinh mã từ schema
local schema = parse_schema(lua_code)
if schema then
    generate_server_code(schema)
else
    error("Schema không hợp lệ.")
end
