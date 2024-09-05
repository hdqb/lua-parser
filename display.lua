-- Giả sử processor.lua và display.lua đã được yêu cầu
local processor = require('processor')

-- Giả sử bạn đã có schema từ file schema.lua
local schema = require('schema')

-- Đây là file display.lua để hiển thị thông tin từ schema đã xử lý bởi processor

-- Hàm để in thông tin endpoint
local function display_endpoint_info(endpoint)
    print("--------------------------------------------------")
    print("Endpoint Name: " .. endpoint.name)
    print("Method: " .. endpoint.method)
    print("Path: " .. endpoint.path)

    -- Hiển thị các tham số (params)
    if endpoint.params and #endpoint.params > 0 then
        print("Parameters:")
        for _, param in ipairs(endpoint.params) do
            local required = param.required and "(required)" or "(optional)"
            print(string.format("  - %s: %s %s", param.name, param.type, required))
            if param.example then
                print(string.format("    Example: %s", param.example))
            end
        end
    else
        print("Parameters: None")
    end

    -- Hiển thị các phản hồi (responses)
    if endpoint.responses then
        print("Responses:")
        for response_type, response_info in pairs(endpoint.responses) do
            print(string.format("  - %s (%d)", response_type, response_info.status_code))
            for _, field in ipairs(response_info.fields) do
                print(string.format("    Field: %s (%s)", field.name, field.type))
            end
        end
    else
        print("Responses: None")
    end

    -- Hiển thị bảo mật (security)
    if endpoint.security then
        print("Security:")
        if endpoint.security.oauth then print("  - OAuth enabled") end
        if endpoint.security.jwt then print("  - JWT enabled") end
        if endpoint.security.api_key then print("  - API Key enabled") end
        if endpoint.security.cors then
            print("  - CORS allowed origins: " .. table.concat(endpoint.security.cors.allowed_origins, ", "))
        end
    else
        print("Security: None")
    end

    -- Hiển thị giới hạn truy cập (rate limit)
    if endpoint.rate_limit then
        print(string.format("Rate Limit: %d requests per %d seconds", endpoint.rate_limit.limit, endpoint.rate_limit.window))
    else
        print("Rate Limit: None")
    end

    -- Hiển thị quốc tế hóa (i18n)
    if endpoint.i18n and #endpoint.i18n.supported_languages > 0 then
        print("Supported Languages: " .. table.concat(endpoint.i18n.supported_languages, ", "))
    else
        print("Supported Languages: None")
    end

    -- Hiển thị các middlewares
    if endpoint.middlewares and #endpoint.middlewares > 0 then
        print("Middlewares: " .. table.concat(endpoint.middlewares, ", "))
    else
        print("Middlewares: None")
    end

    print("--------------------------------------------------")
end

-- Hàm hiển thị thông tin schema
local function display_schema(schema)
    print("==================================================")
    print("API Name: " .. schema.name)
    print("Version: " .. schema.version)
    if schema.description then
        print("Description: " .. schema.description)
    else
        print("Description: None")
    end

    -- Hiển thị thông tin cơ sở dữ liệu (nếu có)
    if schema.database then
        print("Database Configuration:")
        print("  Type: " .. schema.database.type)
        print("  Host: " .. schema.database.host)
        print("  Port: " .. schema.database.port)
        print("  Username: " .. schema.database.username)
    else
        print("Database: None")
    end

    -- Hiển thị thông tin các endpoint
    if schema.endpoints then
        print("Endpoints:")
        for _, endpoint in ipairs(schema.endpoints) do
            display_endpoint_info(endpoint)
        end
    else
        print("Endpoints: None")
    end
end


-- Phân tích schema
local parsed_schema = processor.parse_schema(schema)

-- Hiển thị toàn bộ schema
display_schema(parsed_schema)
