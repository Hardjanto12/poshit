package main

import (
	"log"
	"time"

	"gorm.io/gorm"
)

func seedData(db *gorm.DB) {
    // Seed only if no users exist
    var count int64
    if err := db.Model(&User{}).Count(&count).Error; err != nil {
        log.Printf("seed: count users failed: %v", err)
        return
    }
    if count > 0 {
        return
    }

    now := time.Now().Format(time.RFC3339)

    // Create default admin and organization
    // Seed with bcrypt-hashed password 'admin123'
    hashed := "$2a$10$C1c1W7m8l3RkJ0d7qKZkWeK0zO7pZyP0e7Q2mF1oXq1M7vJ3m7z0e" // precomputed bcrypt for 'admin123'
    admin := User{ Name: "Admin", Username: "admin", Password: hashed, DateCreated: now, DateUpdated: now }
    if err := db.Create(&admin).Error; err != nil {
        log.Printf("seed: create admin failed: %v", err)
        return
    }
    org := Organization{Name: "Demo Store", DateCreated: now, DateUpdated: now}
    if err := db.Create(&org).Error; err != nil { log.Printf("seed: create org failed: %v", err); return }
    ou := OrganizationUser{OrganizationID: org.ID, UserID: admin.ID, Role: "owner", IsActive: true, DateCreated: now, DateUpdated: now}
    if err := db.Create(&ou).Error; err != nil { log.Printf("seed: create org user failed: %v", err); return }

    // Settings defaults
    defaults := []Setting{
        {OrganizationID: org.ID, UserID: admin.ID, Key: "printer_type", Value: "Bluetooth"},
        {OrganizationID: org.ID, UserID: admin.ID, Key: "business_name", Value: "My Business"},
        {OrganizationID: org.ID, UserID: admin.ID, Key: "receipt_footer", Value: "Thank you for your purchase!"},
        {OrganizationID: org.ID, UserID: admin.ID, Key: "use_inventory_tracking", Value: "true"},
        {OrganizationID: org.ID, UserID: admin.ID, Key: "use_sku_field", Value: "true"},
    }
    for _, s := range defaults {
        _ = db.Save(&s).Error
    }

    // Sample products
    p1sku := "SKU-1001"
    p2sku := "SKU-1002"
    p3sku := "SKU-1003"
    coffeeIcon := "fastfood"
    milkIcon := "local_drink"
    sugarIcon := "icecream"
    products := []Product{
        {OrganizationID: org.ID, UserID: admin.ID, Name: "Coffee Beans 1kg", Price: 15.50, SKU: &p1sku, Icon: &coffeeIcon, StockQuantity: 100, DateCreated: now, DateUpdated: now},
        {OrganizationID: org.ID, UserID: admin.ID, Name: "Milk 1L", Price: 1.20, SKU: &p2sku, Icon: &milkIcon, StockQuantity: 200, DateCreated: now, DateUpdated: now},
        {OrganizationID: org.ID, UserID: admin.ID, Name: "Sugar 500g", Price: 0.80, SKU: &p3sku, Icon: &sugarIcon, StockQuantity: 150, DateCreated: now, DateUpdated: now},
    }
    if err := db.Create(&products).Error; err != nil {
        log.Printf("seed: create products failed: %v", err)
        return
    }

    // One sample transaction with two items
    txn := Transaction{
        OrganizationID:  org.ID,
        UserID:          admin.ID,
        TotalAmount:     15.50 + (1.20 * 2),
        AmountReceived:  20.00,
        Change:          20.00 - (15.50 + 2.40),
        TransactionDate: now,
        DateCreated:     now,
        DateUpdated:     now,
    }
    if err := db.Create(&txn).Error; err != nil {
        log.Printf("seed: create transaction failed: %v", err)
        return
    }
    items := []TransactionItem{
        {TransactionID: txn.ID, ProductID: products[0].ID, Quantity: 1, PriceAtTransaction: 15.50, DateCreated: now, DateUpdated: now},
        {TransactionID: txn.ID, ProductID: products[1].ID, Quantity: 2, PriceAtTransaction: 1.20, DateCreated: now, DateUpdated: now},
    }
    if err := db.Create(&items).Error; err != nil {
        log.Printf("seed: create transaction items failed: %v", err)
        return
    }
    // Adjust stock quantities
    _ = db.Model(&Product{}).Where("id = ? AND user_id = ?", products[0].ID, admin.ID).UpdateColumn("stock_quantity", gorm.Expr("stock_quantity - ?", 1)).Error
    _ = db.Model(&Product{}).Where("id = ? AND user_id = ?", products[1].ID, admin.ID).UpdateColumn("stock_quantity", gorm.Expr("stock_quantity - ?", 2)).Error
}


