package main

import (
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
)

// Models (aligned to Flutter app domain)
type User struct {
    ID          uint   `gorm:"primaryKey" json:"id"`
    Name        string `json:"name"`
    Username    string `gorm:"uniqueIndex" json:"username"`
    Password    string `json:"password"` // store hashed
    DateCreated string `json:"date_created"`
    DateUpdated string `json:"date_updated"`
}

type Organization struct {
    ID          uint   `gorm:"primaryKey" json:"id"`
    Name        string `json:"name"`
    DateCreated string `json:"date_created"`
    DateUpdated string `json:"date_updated"`
}

type OrganizationUser struct {
    OrganizationID uint   `gorm:"primaryKey" json:"organization_id"`
    UserID         uint   `gorm:"primaryKey" json:"user_id"`
    Role           string `json:"role"` // owner, manager, cashier
    IsActive       bool   `json:"is_active"`
    DateCreated    string `json:"date_created"`
    DateUpdated    string `json:"date_updated"`
}

type Product struct {
    ID           uint    `gorm:"primaryKey" json:"id"`
    OrganizationID uint  `json:"organization_id"`
    UserID       uint    `json:"user_id"`
    Name         string  `json:"name"`
    Price        float64 `json:"price"`
    SKU          *string `json:"sku"`
    StockQuantity int    `json:"stock_quantity"`
    DateCreated  string  `json:"date_created"`
    DateUpdated  string  `json:"date_updated"`
}

type Transaction struct {
    ID              uint    `gorm:"primaryKey" json:"id"`
    OrganizationID  uint    `json:"organization_id"`
    UserID          uint    `json:"user_id"`
    TotalAmount     float64 `json:"total_amount"`
    AmountReceived  float64 `json:"amount_received"`
    Change          float64 `json:"change"`
    TransactionDate string  `json:"transaction_date"`
    DateCreated     string  `json:"date_created"`
    DateUpdated     string  `json:"date_updated"`
}

type TransactionItem struct {
    ID                 uint    `gorm:"primaryKey" json:"id"`
    TransactionID      uint    `json:"transaction_id"`
    ProductID          uint    `json:"product_id"`
    Quantity           int     `json:"quantity"`
    PriceAtTransaction float64 `json:"price_at_transaction"`
    DateCreated        string  `json:"date_created"`
    DateUpdated        string  `json:"date_updated"`
}

type Setting struct {
    OrganizationID uint   `gorm:"primaryKey" json:"organization_id"`
    UserID uint   `gorm:"primaryKey" json:"user_id"`
    Key    string `gorm:"primaryKey" json:"key"`
    Value  string `json:"value"`
}

// Global state
var (
    db          *gorm.DB
    jwtSecret   []byte
    tokenExpiry = time.Hour * 72
)

func nowISO() string { return time.Now().Format(time.RFC3339) }

func main() {
    dsn := os.Getenv("MYSQL_DSN")
    if dsn == "" {
        // Example: user:pass@tcp(127.0.0.1:3306)/poshit?charset=utf8mb4&parseTime=True&loc=Local
        dsn = "root@tcp(127.0.0.1:3306)/poshit?charset=utf8mb4&parseTime=True&loc=Local"
    }
    secret := os.Getenv("JWT_SECRET")
    if secret == "" {
        secret = "dev-secret-change-me"
    }
    jwtSecret = []byte(secret)

    var err error
    db, err = gorm.Open(mysql.Open(dsn), &gorm.Config{})
    if err != nil {
        log.Fatalf("failed to connect database: %v", err)
    }

    if err := db.AutoMigrate(&User{}, &Organization{}, &OrganizationUser{}, &Product{}, &Transaction{}, &TransactionItem{}, &Setting{}); err != nil {
        log.Fatalf("failed to migrate: %v", err)
    }

    // Seed initial data if DB is empty
    seedData(db)

    r := gin.Default()

    api := r.Group("/api/v1")
    {
        api.POST("/auth/login", loginHandler)
        api.POST("/auth/register", registerHandler)
        api.GET("/health", func(c *gin.Context) { c.JSON(http.StatusOK, gin.H{"status": "ok"}) })

        auth := api.Group("")
        auth.Use(authMiddleware())
        {
            auth.GET("/auth/me", meHandler)

            // User management (owner/manager)
            auth.GET("/users", listUsers)
            auth.POST("/users", createUser)
            auth.PUT("/users/:id", updateUser)
            auth.POST("/users/:id/reset-password", resetUserPassword)

            // Products
            auth.GET("/products", listProducts)
            auth.POST("/products", createProduct)
            auth.GET("/products/:id", getProduct)
            auth.PUT("/products/:id", updateProduct)
            auth.DELETE("/products/:id", deleteProduct)
            auth.GET("/products/search", searchProducts)

            // Transactions
            auth.GET("/transactions", listTransactions)
            auth.GET("/transactions/:id", getTransaction)
            auth.GET("/transactions/:id/items", getTransactionItems)
            auth.POST("/transactions", createTransaction)
            auth.DELETE("/transactions/:id", deleteTransaction)

            // Settings
            auth.GET("/settings/:key", getSetting)
            auth.PUT("/settings/:key", putSetting)

            // Analytics
            auth.GET("/analytics/today-summary", todaySummary)
            auth.GET("/analytics/top-selling", topSelling)
        }
    }

    port := os.Getenv("PORT")
    if port == "" { port = "8080" }
    if err := r.Run(":" + port); err != nil {
        log.Fatal(err)
    }
}

// Auth helpers
func generateToken(userID uint) (string, error) {
    claims := jwt.MapClaims{
        "sub": userID,
        "exp": time.Now().Add(tokenExpiry).Unix(),
        "iat": time.Now().Unix(),
    }
    token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
    return token.SignedString(jwtSecret)
}

func authMiddleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        header := c.GetHeader("Authorization")
        if header == "" || !strings.HasPrefix(header, "Bearer ") {
            c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "missing token"})
            return
        }
        tokenStr := strings.TrimPrefix(header, "Bearer ")
        token, err := jwt.Parse(tokenStr, func(token *jwt.Token) (interface{}, error) { return jwtSecret, nil })
        if err != nil || !token.Valid {
            c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "invalid token"})
            return
        }
        claims, ok := token.Claims.(jwt.MapClaims)
        if !ok {
            c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "invalid claims"})
            return
        }
        sub := claims["sub"]
        switch v := sub.(type) {
        case float64:
            c.Set("userID", uint(v))
        case int:
            c.Set("userID", uint(v))
        default:
            c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "bad subject"})
            return
        }
        c.Next()
    }
}

// Auth handlers
type loginRequest struct {
    Username string `json:"username"`
    Password string `json:"password"`
}

func loginHandler(c *gin.Context) {
    var req loginRequest
    if err := c.BindJSON(&req); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": "bad request"})
        return
    }
    var user User
    if err := db.Where("username = ?", req.Username).First(&user).Error; err != nil {
        c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid credentials"})
        return
    }
    // Compare bcrypt hashed password
    if err := bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(req.Password)); err != nil {
        c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid credentials"})
        return
    }
    // Load primary organization membership
    var orgUser OrganizationUser
    if err := db.Where("user_id = ? AND is_active = ?", user.ID, true).First(&orgUser).Error; err != nil {
        c.JSON(http.StatusUnauthorized, gin.H{"error": "user has no active organization"})
        return
    }
    var org Organization
    _ = db.First(&org, orgUser.OrganizationID).Error
    token, _ := generateToken(user.ID)
    c.JSON(http.StatusOK, gin.H{
        "token": token,
        "user": user,
        "organization": org,
        "role": orgUser.Role,
    })
}

func registerHandler(c *gin.Context) {
    var user User
    if err := c.BindJSON(&user); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": "bad request"})
        return
    }
    now := nowISO()
    // Hash password
    hashed, err := bcrypt.GenerateFromPassword([]byte(user.Password), bcrypt.DefaultCost)
    if err != nil { c.JSON(http.StatusBadRequest, gin.H{"error": "hash error"}); return }
    user.Password = string(hashed)
    user.DateCreated = now
    user.DateUpdated = now
    if err := db.Create(&user).Error; err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }
    // Create a new organization and membership with owner role
    org := Organization{Name: user.Name + "'s Store", DateCreated: now, DateUpdated: now}
    if err := db.Create(&org).Error; err == nil {
        _ = db.Create(&OrganizationUser{OrganizationID: org.ID, UserID: user.ID, Role: "owner", IsActive: true, DateCreated: now, DateUpdated: now}).Error
    }
    c.JSON(http.StatusCreated, user)
}

func meHandler(c *gin.Context) {
    uid := c.MustGet("userID").(uint)
    var user User
    if err := db.First(&user, uid).Error; err != nil {
        c.JSON(http.StatusNotFound, gin.H{"error": "user not found"})
        return
    }
    var orgUser OrganizationUser
    _ = db.Where("user_id = ? AND is_active = ?", uid, true).First(&orgUser).Error
    var org Organization
    _ = db.First(&org, orgUser.OrganizationID).Error
    c.JSON(http.StatusOK, gin.H{"user": user, "organization": org, "role": orgUser.Role})
}

// Product handlers
func listProducts(c *gin.Context) {
    uid := c.MustGet("userID").(uint)
    var orgUser OrganizationUser
    _ = db.Where("user_id = ? AND is_active = ?", uid, true).First(&orgUser).Error
    var products []Product
    db.Where("organization_id = ?", orgUser.OrganizationID).Order("name asc").Find(&products)
    c.JSON(http.StatusOK, products)
}

func createProduct(c *gin.Context) {
    uid := c.MustGet("userID").(uint)
    var orgUser OrganizationUser
    _ = db.Where("user_id = ? AND is_active = ?", uid, true).First(&orgUser).Error
    var p Product
    if err := c.BindJSON(&p); err != nil { c.JSON(http.StatusBadRequest, gin.H{"error": "bad request"}); return }
    now := nowISO()
    p.UserID = uid
    p.OrganizationID = orgUser.OrganizationID
    p.DateCreated = now
    p.DateUpdated = now
    if err := db.Create(&p).Error; err != nil { c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()}); return }
    c.JSON(http.StatusCreated, p)
}

func getProduct(c *gin.Context) {
    uid := c.MustGet("userID").(uint)
    var orgUser OrganizationUser
    _ = db.Where("user_id = ? AND is_active = ?", uid, true).First(&orgUser).Error
    id, _ := strconv.Atoi(c.Param("id"))
    var p Product
    if err := db.Where("id = ? AND organization_id = ?", id, orgUser.OrganizationID).First(&p).Error; err != nil {
        c.JSON(http.StatusNotFound, gin.H{"error": "not found"})
        return
    }
    c.JSON(http.StatusOK, p)
}

func updateProduct(c *gin.Context) {
    uid := c.MustGet("userID").(uint)
    var orgUser OrganizationUser
    _ = db.Where("user_id = ? AND is_active = ?", uid, true).First(&orgUser).Error
    id, _ := strconv.Atoi(c.Param("id"))
    var p Product
    if err := db.Where("id = ? AND organization_id = ?", id, orgUser.OrganizationID).First(&p).Error; err != nil {
        c.JSON(http.StatusNotFound, gin.H{"error": "not found"})
        return
    }
    var body Product
    if err := c.BindJSON(&body); err != nil { c.JSON(http.StatusBadRequest, gin.H{"error": "bad request"}); return }
    p.Name = body.Name
    p.Price = body.Price
    p.SKU = body.SKU
    p.StockQuantity = body.StockQuantity
    p.DateUpdated = nowISO()
    if err := db.Save(&p).Error; err != nil { c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()}); return }
    c.JSON(http.StatusOK, p)
}

func deleteProduct(c *gin.Context) {
    uid := c.MustGet("userID").(uint)
    var orgUser OrganizationUser
    _ = db.Where("user_id = ? AND is_active = ?", uid, true).First(&orgUser).Error
    id, _ := strconv.Atoi(c.Param("id"))
    if err := db.Where("id = ? AND organization_id = ?", id, orgUser.OrganizationID).Delete(&Product{}).Error; err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }
    c.Status(http.StatusNoContent)
}

func searchProducts(c *gin.Context) {
    uid := c.MustGet("userID").(uint)
    var orgUser OrganizationUser
    _ = db.Where("user_id = ? AND is_active = ?", uid, true).First(&orgUser).Error
    q := c.Query("q")
    var products []Product
    db.Where("organization_id = ? AND (name LIKE ? OR sku LIKE ?)", orgUser.OrganizationID, "%"+q+"%", "%"+q+"%").Order("name asc").Find(&products)
    c.JSON(http.StatusOK, products)
}

// Transaction handlers
type createTransactionRequest struct {
    Transaction
    Items []TransactionItem `json:"items"`
}

func createTransaction(c *gin.Context) {
    uid := c.MustGet("userID").(uint)
    var orgUser OrganizationUser
    _ = db.Where("user_id = ? AND is_active = ?", uid, true).First(&orgUser).Error
    var req createTransactionRequest
    if err := c.BindJSON(&req); err != nil { c.JSON(http.StatusBadRequest, gin.H{"error": "bad request"}); return }
    now := nowISO()
    t := req.Transaction
    t.UserID = uid
    t.OrganizationID = orgUser.OrganizationID
    t.DateCreated = now
    t.DateUpdated = now
    if err := db.Create(&t).Error; err != nil { c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()}); return }
    for i := range req.Items {
        it := req.Items[i]
        it.TransactionID = t.ID
        it.DateCreated = now
        it.DateUpdated = now
        if err := db.Create(&it).Error; err != nil { c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()}); return }
        // Update stock
        db.Model(&Product{}).Where("id = ? AND organization_id = ?", it.ProductID, orgUser.OrganizationID).UpdateColumn("stock_quantity", gorm.Expr("stock_quantity - ?", it.Quantity))
    }
    c.JSON(http.StatusCreated, gin.H{"id": t.ID})
}

func listTransactions(c *gin.Context) {
    uid := c.MustGet("userID").(uint)
    var orgUser OrganizationUser
    _ = db.Where("user_id = ? AND is_active = ?", uid, true).First(&orgUser).Error
    var txs []Transaction
    db.Where("organization_id = ?", orgUser.OrganizationID).Order("transaction_date desc").Find(&txs)
    c.JSON(http.StatusOK, txs)
}

func getTransaction(c *gin.Context) {
    uid := c.MustGet("userID").(uint)
    var orgUser OrganizationUser
    _ = db.Where("user_id = ? AND is_active = ?", uid, true).First(&orgUser).Error
    id, _ := strconv.Atoi(c.Param("id"))
    var t Transaction
    if err := db.Where("id = ? AND organization_id = ?", id, orgUser.OrganizationID).First(&t).Error; err != nil {
        c.JSON(http.StatusNotFound, gin.H{"error": "not found"})
        return
    }
    c.JSON(http.StatusOK, t)
}

func getTransactionItems(c *gin.Context) {
    uid := c.MustGet("userID").(uint)
    var orgUser OrganizationUser
    _ = db.Where("user_id = ? AND is_active = ?", uid, true).First(&orgUser).Error
    id, _ := strconv.Atoi(c.Param("id"))
    var t Transaction
    if err := db.Where("id = ? AND organization_id = ?", id, orgUser.OrganizationID).First(&t).Error; err != nil {
        c.JSON(http.StatusNotFound, gin.H{"error": "not found"})
        return
    }
    // Join to include product name for client receipt display
    type itemRes struct {
        ID                 uint    `json:"id"`
        TransactionID      uint    `json:"transaction_id"`
        ProductID          uint    `json:"product_id"`
        Quantity           int     `json:"quantity"`
        PriceAtTransaction float64 `json:"price_at_transaction"`
        ProductName        string  `json:"product_name"`
        DateCreated        string  `json:"date_created"`
        DateUpdated        string  `json:"date_updated"`
    }
    var rows []itemRes
    db.Raw(`
        SELECT ti.id, ti.transaction_id, ti.product_id, ti.quantity, ti.price_at_transaction,
               COALESCE(p.name, '') as product_name, ti.date_created, ti.date_updated
        FROM transaction_items ti
        LEFT JOIN products p ON ti.product_id = p.id
        WHERE ti.transaction_id = ?
    `, id).Scan(&rows)
    c.JSON(http.StatusOK, rows)
}

func deleteTransaction(c *gin.Context) {
    uid := c.MustGet("userID").(uint)
    var orgUser OrganizationUser
    _ = db.Where("user_id = ? AND is_active = ?", uid, true).First(&orgUser).Error
    id, _ := strconv.Atoi(c.Param("id"))
    if err := db.Where("id = ? AND organization_id = ?", id, orgUser.OrganizationID).Delete(&Transaction{}).Error; err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }
    c.Status(http.StatusNoContent)
}

// Settings
func getSetting(c *gin.Context) {
    uid := c.MustGet("userID").(uint)
    var orgUser OrganizationUser
    _ = db.Where("user_id = ? AND is_active = ?", uid, true).First(&orgUser).Error
    key := c.Param("key")
    var s Setting
    if err := db.Where("organization_id = ? AND `key` = ?", orgUser.OrganizationID, key).First(&s).Error; err != nil {
        c.JSON(http.StatusOK, gin.H{"key": key, "value": nil})
        return
    }
    c.JSON(http.StatusOK, s)
}

func putSetting(c *gin.Context) {
    uid := c.MustGet("userID").(uint)
    var orgUser OrganizationUser
    _ = db.Where("user_id = ? AND is_active = ?", uid, true).First(&orgUser).Error
    key := c.Param("key")
    var body struct{ Value string `json:"value"` }
    if err := c.BindJSON(&body); err != nil { c.JSON(http.StatusBadRequest, gin.H{"error": "bad request"}); return }
    s := Setting{OrganizationID: orgUser.OrganizationID, UserID: uid, Key: key, Value: body.Value}
    if err := db.Save(&s).Error; err != nil { c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()}); return }
    c.JSON(http.StatusOK, s)
}

// Analytics
func todaySummary(c *gin.Context) {
    uid := c.MustGet("userID").(uint)
    var orgUser OrganizationUser
    _ = db.Where("user_id = ? AND is_active = ?", uid, true).First(&orgUser).Error
    today := time.Now().Format("2006-01-02")
    type row struct { TotalRevenue *float64; TotalTransactions *int }
    var r row
    db.Raw("SELECT SUM(total_amount) as total_revenue, COUNT(id) as total_transactions FROM transactions WHERE organization_id = ? AND substr(transaction_date, 1, 10) = ?", orgUser.OrganizationID, today).Scan(&r)
    totalRevenue := 0.0
    totalTransactions := 0
    if r.TotalRevenue != nil { totalRevenue = *r.TotalRevenue }
    if r.TotalTransactions != nil { totalTransactions = *r.TotalTransactions }
    averageSale := 0.0
    if totalTransactions > 0 { averageSale = totalRevenue / float64(totalTransactions) }
    c.JSON(http.StatusOK, gin.H{
        "totalRevenue": totalRevenue,
        "totalTransactions": totalTransactions,
        "averageSaleValue": averageSale,
    })
}

func topSelling(c *gin.Context) {
    uid := c.MustGet("userID").(uint)
    var orgUser OrganizationUser
    _ = db.Where("user_id = ? AND is_active = ?", uid, true).First(&orgUser).Error
    from := time.Now().AddDate(0, 0, -30).Format("2006-01-02")
    type res struct{
        Name string `json:"name"`
        TotalQuantitySold int `json:"totalQuantitySold"`
    }
    var rows []res
    db.Raw(`
        SELECT p.name as name, SUM(ti.quantity) as total_quantity_sold
        FROM transaction_items ti
        JOIN products p ON ti.product_id = p.id
        JOIN transactions t ON ti.transaction_id = t.id
        WHERE p.organization_id = ? AND substr(t.transaction_date, 1, 10) >= ?
        GROUP BY p.name
        ORDER BY total_quantity_sold DESC
        LIMIT 5`, orgUser.OrganizationID, from).Scan(&rows)
    c.JSON(http.StatusOK, rows)
}

// Authorization helpers
func requireRole(c *gin.Context, roles ...string) bool {
    uid := c.MustGet("userID").(uint)
    var orgUser OrganizationUser
    if err := db.Where("user_id = ? AND is_active = ?", uid, true).First(&orgUser).Error; err != nil {
        c.JSON(http.StatusForbidden, gin.H{"error": "no organization"})
        return false
    }
    for _, r := range roles {
        if orgUser.Role == r { return true }
    }
    c.JSON(http.StatusForbidden, gin.H{"error": "insufficient role"})
    return false
}

// User management handlers
func listUsers(c *gin.Context) {
    if !requireRole(c, "owner", "manager") { return }
    uid := c.MustGet("userID").(uint)
    var orgUser OrganizationUser
    _ = db.Where("user_id = ? AND is_active = ?", uid, true).First(&orgUser).Error
    type result struct {
        ID uint `json:"id"`
        Name string `json:"name"`
        Username string `json:"username"`
        Role string `json:"role"`
        IsActive bool `json:"is_active"`
        DateCreated string `json:"date_created"`
        DateUpdated string `json:"date_updated"`
    }
    var rows []result
    db.Raw(`
        SELECT u.id, u.name, u.username, ou.role, ou.is_active, u.date_created, u.date_updated
        FROM organization_users ou
        JOIN users u ON u.id = ou.user_id
        WHERE ou.organization_id = ?
        ORDER BY u.name ASC`, orgUser.OrganizationID).Scan(&rows)
    c.JSON(http.StatusOK, rows)
}

func createUser(c *gin.Context) {
    if !requireRole(c, "owner", "manager") { return }
    uid := c.MustGet("userID").(uint)
    var orgUser OrganizationUser
    _ = db.Where("user_id = ? AND is_active = ?", uid, true).First(&orgUser).Error
    var body struct {
        Name string `json:"name"`
        Username string `json:"username"`
        Password string `json:"password"`
        Role string `json:"role"`
    }
    if err := c.BindJSON(&body); err != nil { c.JSON(http.StatusBadRequest, gin.H{"error": "bad request"}); return }
    now := nowISO()
    hashed, err := bcrypt.GenerateFromPassword([]byte(body.Password), bcrypt.DefaultCost)
    if err != nil { c.JSON(http.StatusBadRequest, gin.H{"error": "hash error"}); return }
    u := User{Name: body.Name, Username: body.Username, Password: string(hashed), DateCreated: now, DateUpdated: now}
    if err := db.Create(&u).Error; err != nil { c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()}); return }
    ou := OrganizationUser{OrganizationID: orgUser.OrganizationID, UserID: u.ID, Role: body.Role, IsActive: true, DateCreated: now, DateUpdated: now}
    if err := db.Create(&ou).Error; err != nil { c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()}); return }
    c.JSON(http.StatusCreated, gin.H{"id": u.ID})
}

func updateUser(c *gin.Context) {
    if !requireRole(c, "owner", "manager") { return }
    uid := c.MustGet("userID").(uint)
    var orgUser OrganizationUser
    _ = db.Where("user_id = ? AND is_active = ?", uid, true).First(&orgUser).Error
    id, _ := strconv.Atoi(c.Param("id"))
    var body struct { Role *string `json:"role"`; IsActive *bool `json:"is_active"` }
    if err := c.BindJSON(&body); err != nil { c.JSON(http.StatusBadRequest, gin.H{"error": "bad request"}); return }
    var ou OrganizationUser
    if err := db.Where("organization_id = ? AND user_id = ?", orgUser.OrganizationID, id).First(&ou).Error; err != nil {
        c.JSON(http.StatusNotFound, gin.H{"error": "not found"}); return
    }
    if body.Role != nil { ou.Role = *body.Role }
    if body.IsActive != nil { ou.IsActive = *body.IsActive }
    ou.DateUpdated = nowISO()
    if err := db.Save(&ou).Error; err != nil { c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()}); return }
    c.JSON(http.StatusOK, gin.H{"ok": true})
}

func resetUserPassword(c *gin.Context) {
    if !requireRole(c, "owner", "manager") { return }
    uid := c.MustGet("userID").(uint)
    var orgUser OrganizationUser
    _ = db.Where("user_id = ? AND is_active = ?", uid, true).First(&orgUser).Error
    id, _ := strconv.Atoi(c.Param("id"))
    var body struct{ NewPassword string `json:"newPassword"` }
    if err := c.BindJSON(&body); err != nil { c.JSON(http.StatusBadRequest, gin.H{"error": "bad request"}); return }
    // ensure target user is in same org
    var ou OrganizationUser
    if err := db.Where("organization_id = ? AND user_id = ?", orgUser.OrganizationID, id).First(&ou).Error; err != nil {
        c.JSON(http.StatusNotFound, gin.H{"error": "not found"}); return
    }
    hashed, err := bcrypt.GenerateFromPassword([]byte(body.NewPassword), bcrypt.DefaultCost)
    if err != nil { c.JSON(http.StatusBadRequest, gin.H{"error": "hash error"}); return }
    if err := db.Model(&User{}).Where("id = ?", id).Updates(map[string]any{"password": string(hashed), "date_updated": nowISO()}).Error; err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()}); return
    }
    c.JSON(http.StatusOK, gin.H{"ok": true})
}


