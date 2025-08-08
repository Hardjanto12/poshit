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

    // Create default admin
    admin := User{
        Name:        "Admin",
        Username:    "admin",
        Password:    "admin123", // plaintext demo
        DateCreated: now,
        DateUpdated: now,
    }
    if err := db.Create(&admin).Error; err != nil {
        log.Printf("seed: create admin failed: %v", err)
        return
    }

    // Settings defaults
    defaults := []Setting{
        {UserID: admin.ID, Key: "printer_type", Value: "Bluetooth"},
        {UserID: admin.ID, Key: "business_name", Value: "My Business"},
        {UserID: admin.ID, Key: "receipt_footer", Value: "Thank you for your purchase!"},
        {UserID: admin.ID, Key: "use_inventory_tracking", Value: "true"},
        {UserID: admin.ID, Key: "use_sku_field", Value: "true"},
    }
    for _, s := range defaults {
        _ = db.Save(&s).Error
    }

    // Sample products
    p1sku := "SKU-1001"
    p2sku := "SKU-1002"
    p3sku := "SKU-1003"
    products := []Product{
        {UserID: admin.ID, Name: "Coffee Beans 1kg", Price: 15.50, SKU: &p1sku, StockQuantity: 100, DateCreated: now, DateUpdated: now},
        {UserID: admin.ID, Name: "Milk 1L", Price: 1.20, SKU: &p2sku, StockQuantity: 200, DateCreated: now, DateUpdated: now},
        {UserID: admin.ID, Name: "Sugar 500g", Price: 0.80, SKU: &p3sku, StockQuantity: 150, DateCreated: now, DateUpdated: now},
    }
    if err := db.Create(&products).Error; err != nil {
        log.Printf("seed: create products failed: %v", err)
        return
    }

    // One sample transaction with two items
    txn := Transaction{
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


