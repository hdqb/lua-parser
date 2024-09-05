-- Schema Processor với hỗ trợ components và examples

-- Hàm hỗ trợ tìm và thay thế ref bằng thành phần từ components
local function resolve_reference(ref, schema)
    local parts = {}
    for part in string.gmatch(ref, "[^/]+") do
        table.insert(parts, part)
    end

    -- Bắt đầu từ schema và đi qua từng phần
    local target = schema
    for i = 2, #parts do  -- Bỏ qua phần đầu '#'
        target = target[parts[i]]
        if not target then
            error("Invalid reference: '" .. ref .. "' not found.")
        end
    end

    return target
end

-- Hàm kiểm tra và xác thực bảo mật OAuth, JWT, API Key, CORS
local function validate_security(endpoint, warnings)
    if endpoint.security then
        if type(endpoint.security) ~= "table" then
            error("Invalid security configuration: 'security' should be a table.")
        end
        if endpoint.security.oauth and type(endpoint.security.oauth) ~= "boolean" then
            error("Invalid security: 'oauth' in endpoint '" .. endpoint.name .. "' should be a boolean.")
        end
        if endpoint.security.jwt and type(endpoint.security.jwt) ~= "boolean" then
            error("Invalid security: 'jwt' in endpoint '" .. endpoint.name .. "' should be a boolean.")
        end
        if endpoint.security.api_key and type(endpoint.security.api_key) ~= "boolean" then
            error("Invalid security: 'api_key' in endpoint '" .. endpoint.name .. "' should be a boolean.")
        end
        if endpoint.security.cors then
            if type(endpoint.security.cors.allowed_origins) ~= "table" then
                error("Invalid CORS configuration: 'allowed_origins' should be a table.")
            end
            for _, origin in ipairs(endpoint.security.cors.allowed_origins) do
                if type(origin) ~= "string" then
                    error("Invalid CORS origin: each entry in 'allowed_origins' should be a string.")
                end
            end
        end
    end
end

-- Hàm kiểm tra các trường cần mã hóa
local function validate_encryption(endpoint, warnings)
    if endpoint.encryption then
        if type(endpoint.encryption.fields) ~= "table" then
            error("Invalid encryption configuration: 'fields' should be a table.")
        end
        for _, field in ipairs(endpoint.encryption.fields) do
            if type(field) ~= "string" then
                error("Invalid encrypted field: 'fields' should contain string values representing field names.")
            end
        end
    end
end

-- Hàm kiểm tra CORS
local function validate_cors(endpoint, warnings)
    if endpoint.security and endpoint.security.cors then
        if type(endpoint.security.cors) ~= "table" then
            error("Invalid CORS configuration: 'cors' should be a table.")
        end
        if endpoint.security.cors.allowed_origins and type(endpoint.security.cors.allowed_origins) ~= "table" then
            error("Invalid CORS: 'allowed_origins' in endpoint '" .. endpoint.name .. "' should be a table.")
        end
    end
end

-- Hàm kiểm tra phiên bản API và đánh dấu lỗi thời (deprecated)
local function validate_versioning(endpoint, warnings)
    if endpoint.version then
        if type(endpoint.version) ~= "string" then
            error("Invalid endpoint: 'version' in endpoint '" .. endpoint.name .. "' should be a string.")
        end
    end
    if endpoint.deprecated and type(endpoint.deprecated) ~= "boolean" then
        table.insert(warnings, "Warning: 'deprecated' for endpoint '" .. endpoint.name .. "' should be a boolean.")
    end
end

-- Hàm kiểm tra cơ sở dữ liệu
local function validate_database_config(schema, warnings)
    if schema.database then
        if type(schema.database) ~= "table" then
            error("Invalid database configuration: 'database' should be a table.")
        end
        if not schema.database.type or type(schema.database.type) ~= "string" then
            error("Invalid database configuration: 'type' field is required and should be a string.")
        end
        if not schema.database.host or type(schema.database.host) ~= "string" then
            error("Invalid database configuration: 'host' field is required and should be a string.")
        end
        if not schema.database.port or type(schema.database.port) ~= "number" then
            error("Invalid database configuration: 'port' field is required and should be a number.")
        end
        if not schema.database.username or type(schema.database.username) ~= "string" then
            error("Invalid database configuration: 'username' field is required and should be a string.")
        end
        if not schema.database.password or type(schema.database.password) ~= "string" then
            table.insert(warnings, "Warning: 'password' field is missing or should be a string.")
        end
    end
end

-- Hàm kiểm tra cơ chế rate limiting
local function validate_rate_limit(endpoint, warnings)
    if endpoint.rate_limit then
        if type(endpoint.rate_limit.limit) ~= "number" or type(endpoint.rate_limit.window) ~= "number" then
            error("Invalid rate limit configuration in endpoint '" .. endpoint.name .. "'. 'limit' and 'window' should be numbers.")
        end
    end
end

-- Hàm kiểm tra quốc tế hóa (i18n)
local function validate_i18n(endpoint, warnings)
    if endpoint.i18n then
        if type(endpoint.i18n.supported_languages) ~= "table" then
            error("Invalid i18n: 'supported_languages' in endpoint '" .. endpoint.name .. "' should be a table.")
        end
        for _, lang in ipairs(endpoint.i18n.supported_languages) do
            if type(lang) ~= "string" then
                error("Invalid i18n: each 'supported_languages' entry in endpoint '" .. endpoint.name .. "' should be a string.")
            end
        end
    end
end

-- Hàm kiểm tra truy cập dựa trên vai trò (role-based access)
local function validate_role_access(endpoint, warnings)
    if endpoint.roles then
        if type(endpoint.roles) ~= "table" then
            error("Invalid roles configuration: 'roles' in endpoint '" .. endpoint.name .. "' should be a table.")
        end
        for _, role in ipairs(endpoint.roles) do
            if type(role) ~= "string" then
                error("Invalid role: Each role in 'roles' for endpoint '" .. endpoint.name .. "' should be a string.")
            end
        end
    end
end

-- Hàm kiểm tra các trường bổ sung hoặc metadata
local function validate_additional_fields(endpoint, warnings)
    if endpoint.description and type(endpoint.description) ~= "string" then
        table.insert(warnings, "Warning: 'description' for endpoint '" .. endpoint.name .. "' should be a string.")
    end
end

-- Hàm kiểm tra tính hợp lệ của từng endpoint và thay thế các ref bằng dữ liệu thực
local function validate_endpoint(endpoint, schema, warnings)
    -- Kiểm tra các thuộc tính chính của endpoint
    if type(endpoint.name) ~= "string" then
        error("Invalid endpoint: 'name' should be a string.")
    end
    if type(endpoint.method) ~= "string" then
        error("Invalid endpoint: 'method' should be a string.")
    end
    if type(endpoint.path) ~= "string" then
        error("Invalid endpoint: 'path' should be a string.")
    end

    -- Chỉ kiểm tra params nếu nó tồn tại (để xử lý các endpoint không có params)
    if endpoint.params then
        if type(endpoint.params) ~= "table" then
            error("Invalid endpoint: 'params' should be a table.")
        end
        -- Kiểm tra chi tiết từng tham số nếu có
        for _, param in ipairs(endpoint.params) do
            if type(param.name) ~= "string" then
                error("Invalid parameter: 'name' in endpoint '" .. endpoint.name .. "' should be a string.")
            end
            if type(param.type) ~= "string" then
                error("Invalid parameter: 'type' in endpoint '" .. endpoint.name .. "' should be a string.")
            end
            if type(param.required) ~= "boolean" then
                table.insert(warnings, "Warning: 'required' for parameter '" .. param.name .. "' in endpoint '" .. endpoint.name .. "' should be a boolean.")
            end
        end
    end

    -- Kiểm tra các phản hồi chi tiết nếu có (và xử lý ref nếu có)
    if endpoint.responses then
        for response_type, response_info in pairs(endpoint.responses) do
            -- Xử lý ref trước khi kiểm tra
            if response_info["ref"] then
                local ref = response_info["ref"]
                endpoint.responses[response_type] = resolve_reference(ref, schema)
            end

            -- Sau khi thay thế ref, tiến hành kiểm tra response
            if type(endpoint.responses[response_type].status_code) ~= "number" then
                error("Invalid response: 'status_code' for response type '" .. response_type .. "' should be a number.")
            end
            if type(endpoint.responses[response_type].fields) ~= "table" then
                error("Invalid response: 'fields' for response type '" .. response_type .. "' should be a table.")
            end
        end
    end

    -- Kiểm tra các thành phần khác của endpoint
    validate_security(endpoint, warnings)
    validate_encryption(endpoint, warnings)
    validate_cors(endpoint, warnings)
    validate_rate_limit(endpoint, warnings)
    validate_versioning(endpoint, warnings)
    validate_i18n(endpoint, warnings)
    validate_role_access(endpoint, warnings)
    validate_additional_fields(endpoint, warnings)
end

-- Hàm chính để phân tích và kiểm tra schema
local function parse_schema(schema)
    -- Kiểm tra các yêu cầu cơ bản của schema
    if type(schema) ~= "table" then
        error("Invalid schema format. Schema should be a table.")
    end

    local warnings = {}

    -- Kiểm tra cơ sở dữ liệu
    validate_database_config(schema, warnings)

    -- Kiểm tra các endpoint
    if schema.endpoints then
        for _, endpoint in ipairs(schema.endpoints) do
            validate_endpoint(endpoint, schema, warnings)
        end
    else
        error("Invalid schema: 'endpoints' is missing or not a table.")
    end

    -- In ra cảnh báo nếu có
    if #warnings > 0 then
        for _, warning in ipairs(warnings) do
            print(warning)
        end
    end

    -- Trả về schema đã được xác thực
    return schema
end

-- Trả về các hàm cần thiết để sử dụng trong generate.lua
return {
    parse_schema = parse_schema
}
