Poshit Backend (Go + MySQL)

Prerequisites

- Go 1.22+
- MySQL 8+

Config

- MYSQL_DSN: e.g. user:pass@tcp(127.0.0.1:3306)/poshit?charset=utf8mb4&parseTime=True&loc=Local
- JWT_SECRET: secret for signing JWT tokens
- PORT: default 8080

Run

```bash
cd backend
go mod tidy
go run .
```

API Base
/api/v1

Auth

- POST /auth/login { username, password }
- POST /auth/register { name, username, password }
- GET /auth/me

Products

- GET /products
- POST /products
- GET /products/:id
- PUT /products/:id
- DELETE /products/:id
- GET /products/search?q=...

Transactions

- GET /transactions
- GET /transactions/:id
- GET /transactions/:id/items
- POST /transactions { transaction fields, items: [] }
- DELETE /transactions/:id

Settings

- GET /settings/:key
- PUT /settings/:key { value }

Analytics

- GET /analytics/today-summary
- GET /analytics/top-selling
