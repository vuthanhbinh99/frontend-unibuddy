# Cấu trúc API service

Thư mục này chỉ chứa lớp giao tiếp HTTP với backend. UI/page không nên tự tạo URL hoặc tự parse envelope ở ngoài các service này.

```text
services/api/
+-- core/
|   +-- api_client.dart      # HTTP transport, bearer token, refresh/retry 401, parse response envelope
|   +-- api_config.dart      # Base URL backend, override bằng --dart-define
|   +-- api_exception.dart   # Lỗi API dùng chung cho UI hiển thị message
+-- modules/
    +-- auth/                # /auth/*
    +-- admin/               # /admin/schools, /admin/reports cho role ADMIN
    +-- student/             # /users/me, /courses, /schedules, notes, flashcards, storage...
    +-- system_admin/        # /admin/storage-usage, audit/error logs, users cho QUAN_TRI_VIEN
```

Quy ước:

- File `core/` là hạ tầng dùng chung, không chứa endpoint nghiệp vụ cụ thể.
- Mỗi thư mục trong `modules/` là một module API theo role/chức năng backend.
- Khi thêm endpoint mới, ưu tiên đặt vào module hiện có đúng trách nhiệm trước khi tạo module mới.
- Không xử lý refresh token trong từng module; `ApiClient` tự refresh và retry protected request một lần.
