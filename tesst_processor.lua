-- Đây là file test_processor.lua để kiểm thử các chức năng của processor.lua

-- Giả sử processor.lua đã được tải
local processor = require('processor')

-- Schema mẫu để kiểm thử
local test_schema = {
    name = "TestAPI",
    version = "1.0",
    description = "API schema for testing purposes.",

    -- Cấu hình cơ sở dữ liệu để kiểm thử
    database = {
        type = "MySQL",
        host = "localhost",
        port = 3306,
        username = "root",
        password = "password123"
    },

    -- Components dùng chung
    components = {
        responses = {
            Success = {
                status_code = 200,
                description = "Success response",
                fields = {
                    { name = "id", type = "integer" },
                    { name = "message", type = "string" }
                }
            },
            NotFound = {
                status_code = 404,
                description = "Resource not found",
                fields = {
                    { name = "error", type = "string" },
                    { name = "message", type = "string" }
                }
            }
        },
        parameters = {
            UserId = {
                name = "id",
                type = "integer",
                required = true,
                description = "User identifier",
                example = 123
            }
        }
    },

    -- Endpoint dùng để kiểm thử
    endpoints = {
        {
            name = "getUser",
            method = "GET",
            path = "/user/{id}",
            params = {
                { name = "id", type = "integer", required = true, example = 101 }
            },
            responses = {
                success = {
                    ref = "#/components/responses/Success" -- Tham chiếu đến response dùng chung, thay thế $ref thành ref
                },
                not_found = {
                    ref = "#/components/responses/NotFound" -- Tham chiếu đến response dùng chung
                }
            },
            description = "Retrieve user details by ID"
        }
    }
}

-- Hàm helper để in ra kết quả kiểm tra
local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error(message .. " - Expected: " .. tostring(expected) .. ", but got: " .. tostring(actual))
    else
        print("✔️ " .. message)
    end
end

-- Bắt đầu test

-- Test 1: Kiểm tra phân tích schema thành công
local function test_parse_schema_success()
    local parsed_schema = processor.parse_schema(test_schema)
    assert_equal(parsed_schema.name, "TestAPI", "Test 1: Schema name should be 'TestAPI'")
    assert_equal(parsed_schema.version, "1.0", "Test 1: Schema version should be '1.0'")
    assert_equal(type(parsed_schema.endpoints), "table", "Test 1: Endpoints should be a table")
end

-- Test 2: Kiểm tra ref và thay thế đúng các thành phần dùng chung
local function test_resolve_ref()
    local parsed_schema = processor.parse_schema(test_schema)
    local endpoint = parsed_schema.endpoints[1]
    
    -- Kiểm tra response "success" đã được thay thế đúng
    assert_equal(endpoint.responses.success.status_code, 200, "Test 2: Success response status code should be 200")
    assert_equal(endpoint.responses.success.description, "Success response", "Test 2: Success response description should be correct")
    
    -- Kiểm tra response "not_found" đã được thay thế đúng
    assert_equal(endpoint.responses.not_found.status_code, 404, "Test 2: NotFound response status code should be 404")
    assert_equal(endpoint.responses.not_found.description, "Resource not found", "Test 2: NotFound response description should be correct")
end

-- Test 3: Kiểm tra lỗi khi schema thiếu endpoint
local function test_missing_endpoints()
    local broken_schema = {
        name = "BrokenAPI",
        version = "1.0"
        -- thiếu phần 'endpoints'
    }
    
    local success, err = pcall(function() processor.parse_schema(broken_schema) end)
    assert_equal(success, false, "Test 3: Missing 'endpoints' should raise an error")
    print("✔️ Test 3: Error message - " .. err)
end

-- Test 4: Kiểm tra lỗi với định nghĩa ref sai
local function test_invalid_ref()
    local invalid_ref_schema = {
        name = "InvalidRefAPI",
        version = "1.0",
        endpoints = {
            {
                name = "getInvalidUser",
                method = "GET",
                path = "/user/{id}",
                responses = {
                    invalid_ref = {
                        ref = "#/components/responses/NonExistentResponse" -- Tham chiếu không tồn tại
                    }
                }
            }
        }
    }

    local success, err = pcall(function() processor.parse_schema(invalid_ref_schema) end)
    assert_equal(success, false, "Test 4: Invalid ref should raise an error")
    print("✔️ Test 4: Error message - " .. err)
end

-- Test 5: Kiểm tra rate limiting trong endpoint
local function test_rate_limiting()
    local schema_with_rate_limit = {
        name = "RateLimitedAPI",
        version = "1.0",
        endpoints = {
            {
                name = "limitedEndpoint",
                method = "GET",
                path = "/limited",
                rate_limit = {
                    limit = 10,
                    window = 60
                }
            }
        }
    }

    local parsed_schema = processor.parse_schema(schema_with_rate_limit)
    local endpoint = parsed_schema.endpoints[1]
    assert_equal(endpoint.rate_limit.limit, 10, "Test 5: Rate limit should be 10 requests")
    assert_equal(endpoint.rate_limit.window, 60, "Test 5: Rate window should be 60 seconds")
end

-- Chạy tất cả các test
local function run_all_tests()
    print("Running tests...")
    test_parse_schema_success()
    test_resolve_ref()
    test_missing_endpoints()
    test_invalid_ref()
    test_rate_limiting()
    print("All tests completed successfully!")
end

-- Bắt đầu chạy các test
run_all_tests()
