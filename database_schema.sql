-- SQL script to create the database schema for the Poshit application (MariaDB/MySQL)

-- Table to store user information
CREATE TABLE users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    username VARCHAR(100) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    date_created DATETIME NOT NULL,
    date_updated DATETIME NOT NULL
);

-- Table to store product information
CREATE TABLE products (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    name VARCHAR(255) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    sku VARCHAR(100),
    stock_quantity INT DEFAULT 0,
    date_created DATETIME NOT NULL,
    date_updated DATETIME NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Table to store transaction information
CREATE TABLE transactions (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    amount_received DECIMAL(10,2) NOT NULL,
    `change` DECIMAL(10,2) NOT NULL,
    transaction_date DATETIME NOT NULL,
    date_created DATETIME NOT NULL,
    date_updated DATETIME NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Table to store individual items within a transaction
CREATE TABLE transaction_items (
    id INT PRIMARY KEY AUTO_INCREMENT,
    transaction_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    price_at_transaction DECIMAL(10,2) NOT NULL,
    date_created DATETIME NOT NULL,
    date_updated DATETIME NOT NULL,
    FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
);

-- Table to store application settings for each user
CREATE TABLE settings (
    user_id INT NOT NULL,
    `key` VARCHAR(255) NOT NULL,
    value TEXT NOT NULL,
    PRIMARY KEY (user_id, `key`),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
