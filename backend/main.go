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

type Product struct {
    ID           uint    `gorm:"primaryKey" json:"id"`
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

    if err := db.AutoMigrate(&User{}, &Product{}, &Transaction{}, &TransactionItem{}, &Setting{}); err != nil {
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
    // For demo: plaintext compare (replace with bcrypt in production)
    if user.Password != req.Password {
        c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid credentials"})
        return
    }
    token, _ := generateToken(user.ID)
    c.JSON(http.StatusOK, gin.H{"token": token, "user": user})
}

func registerHandler(c *gin.Context) {
    var user User
    if err := c.BindJSON(&user); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": "bad request"})
        return
    }
    now := nowISO()
    user.DateCreated = now
    user.DateUpdated = now
    if err := db.Create(&user).Error; err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
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
    c.JSON(http.StatusOK, user)
}

// Product handlers
func listProducts(c *gin.Context) {
    uid := c.MustGet("userID").(uint)
    var products []Product
    db.Where("user_id = ?", uid).Order("name asc").Find(&products)
    c.JSON(http.StatusOK, products)
}

func createProduct(c *gin.Context) {
    uid := c.MustGet("userID").(uint)
    var p Product
    if err := c.BindJSON(&p); err != nil { c.JSON(http.StatusBadRequest, gin.H{"error": "bad request"}); return }
    now := nowISO()
    p.UserID = uid
    p.DateCreated = now
    p.DateUpdated = now
    if err := db.Create(&p).Error; err != nil { c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()}); return }
    c.JSON(http.StatusCreated, p)
}

func getProduct(c *gin.Context) {
    uid := c.MustGet("userID").(uint)
    id, _ := strconv.Atoi(c.Param("id"))
    var p Product
    if err := db.Where("id = ? AND user_id = ?", id, uid).First(&p).Error; err != nil {
        c.JSON(http.StatusNotFound, gin.H{"error": "not found"})
        return
    }
    c.JSON(http.StatusOK, p)
}

func updateProduct(c *gin.Context) {
    uid := c.MustGet("userID").(uint)
    id, _ := strconv.Atoi(c.Param("id"))
    var p Product
    if err := db.Where("id = ? AND user_id = ?", id, uid).First(&p).Error; err != nil {
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
    id, _ := strconv.Atoi(c.Param("id"))
    if err := db.Where("id = ? AND user_id = ?", id, uid).Delete(&Product{}).Error; err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }
    c.Status(http.StatusNoContent)
}

func searchProducts(c *gin.Context) {
    uid := c.MustGet("userID").(uint)
    q := c.Query("q")
    var products []Product
    db.Where("user_id = ? AND (name LIKE ? OR sku LIKE ?)", uid, "%"+q+"%", "%"+q+"%").Order("name asc").Find(&products)
    c.JSON(http.StatusOK, products)
}

// Transaction handlers
type createTransactionRequest struct {
    Transaction
    Items []TransactionItem `json:"items"`
}

func createTransaction(c *gin.Context) {
    uid := c.MustGet("userID").(uint)
    var req createTransactionRequest
    if err := c.BindJSON(&req); err != nil { c.JSON(http.StatusBadRequest, gin.H{"error": "bad request"}); return }
    now := nowISO()
    t := req.Transaction
    t.UserID = uid
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
        db.Model(&Product{}).Where("id = ? AND user_id = ?", it.ProductID, uid).UpdateColumn("stock_quantity", gorm.Expr("stock_quantity - ?", it.Quantity))
    }
    c.JSON(http.StatusCreated, gin.H{"id": t.ID})
}

func listTransactions(c *gin.Context) {
    uid := c.MustGet("userID").(uint)
    var txs []Transaction
    db.Where("user_id = ?", uid).Order("transaction_date desc").Find(&txs)
    c.JSON(http.StatusOK, txs)
}

func getTransaction(c *gin.Context) {
    uid := c.MustGet("userID").(uint)
    id, _ := strconv.Atoi(c.Param("id"))
    var t Transaction
    if err := db.Where("id = ? AND user_id = ?", id, uid).First(&t).Error; err != nil {
        c.JSON(http.StatusNotFound, gin.H{"error": "not found"})
        return
    }
    c.JSON(http.StatusOK, t)
}

func getTransactionItems(c *gin.Context) {
    uid := c.MustGet("userID").(uint)
    id, _ := strconv.Atoi(c.Param("id"))
    var t Transaction
    if err := db.Where("id = ? AND user_id = ?", id, uid).First(&t).Error; err != nil {
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
    id, _ := strconv.Atoi(c.Param("id"))
    if err := db.Where("id = ? AND user_id = ?", id, uid).Delete(&Transaction{}).Error; err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }
    c.Status(http.StatusNoContent)
}

// Settings
func getSetting(c *gin.Context) {
    uid := c.MustGet("userID").(uint)
    key := c.Param("key")
    var s Setting
    if err := db.Where("user_id = ? AND `key` = ?", uid, key).First(&s).Error; err != nil {
        c.JSON(http.StatusOK, gin.H{"key": key, "value": nil})
        return
    }
    c.JSON(http.StatusOK, s)
}

func putSetting(c *gin.Context) {
    uid := c.MustGet("userID").(uint)
    key := c.Param("key")
    var body struct{ Value string `json:"value"` }
    if err := c.BindJSON(&body); err != nil { c.JSON(http.StatusBadRequest, gin.H{"error": "bad request"}); return }
    s := Setting{UserID: uid, Key: key, Value: body.Value}
    if err := db.Save(&s).Error; err != nil { c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()}); return }
    c.JSON(http.StatusOK, s)
}

// Analytics
func todaySummary(c *gin.Context) {
    uid := c.MustGet("userID").(uint)
    today := time.Now().Format("2006-01-02")
    type row struct { TotalRevenue *float64; TotalTransactions *int }
    var r row
    db.Raw("SELECT SUM(total_amount) as total_revenue, COUNT(id) as total_transactions FROM transactions WHERE user_id = ? AND substr(transaction_date, 1, 10) = ?", uid, today).Scan(&r)
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
        WHERE p.user_id = ? AND substr(t.transaction_date, 1, 10) >= ?
        GROUP BY p.name
        ORDER BY total_quantity_sold DESC
        LIMIT 5`, uid, from).Scan(&rows)
    c.JSON(http.StatusOK, rows)
}


