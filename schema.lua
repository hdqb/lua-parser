-- Đây là file schema.lua chứa schema mẫu của API

local schema = {
    name = "MyAPI",
    version = "1.1",
    description = "This is a sample API schema with security, database, and advanced features.",
    
    -- Cấu hình cơ sở dữ liệu
    database = {
        type = "PostgreSQL",  -- Loại cơ sở dữ liệu: MySQL, PostgreSQL, MongoDB, v.v.
        host = "127.0.0.1",
        port = 5432,
        username = "admin",
        password = "password123",
        database_name = "my_api_db"
    },
    
    -- Định nghĩa các endpoint
    endpoints = {
        -- Endpoint lấy thông tin người dùng
        {
            name = "getUser",
            method = "GET",
            path = "/user/{id}",
            headers = {
                { name = "Authorization", required = true }  -- Kiểm tra bảo mật
            },
            query_params = {
                { name = "verbose", type = "boolean" }
            },
            params = {
                { name = "id", type = "integer", required = true }
            },
            security = {
                oauth = true,
                jwt = true,
                api_key = false,
                cors = {
                    allowed_origins = { "https://example.com", "https://another-example.com" }
                }
            },
            encryption = {
                fields = { "password", "ssn" }  -- Mã hóa các trường nhạy cảm
            },
            i18n = {
                supported_languages = { "en", "fr", "es" }
            },
            responses = {
                success = {
                    status_code = 200,
                    fields = {
                        { name = "id", type = "integer" },
                        { name = "name", type = "string" },
                        { name = "email", type = "string" }
                    }
                },
                validation_error = {
                    status_code = 400,
                    fields = {
                        { name = "error", type = "string" },
                        { name = "message", type = "string" }
                    }
                },
                server_error = {
                    status_code = 500,
                    fields = {
                        { name = "error", type = "string" },
                        { name = "message", type = "string" }
                    }
                }
            },
            description = "Get user information by ID",
            middlewares = { "auth", "logging" },
            rate_limit = { limit = 100, window = 60 }  -- Giới hạn tần suất yêu cầu
        },

        -- Endpoint tạo mới người dùng
        {
            name = "createUser",
            method = "POST",
            path = "/user",
            params = {
                { name = "name", type = "string", required = true },
                { name = "email", type = "string", required = true }
            },
            security = {
                oauth = true,
                jwt = true
            },
            responses = {
                success = {
                    status_code = 201,
                    fields = {
                        { name = "id", type = "integer" },
                        { name = "message", type = "string" }
                    }
                },
                bad_request = {
                    status_code = 400,
                    fields = {
                        { name = "error", type = "string" },
                        { name = "message", type = "string" }
                    }
                }
            },
            description = "Create a new user"
        }
    }
}

return schema
