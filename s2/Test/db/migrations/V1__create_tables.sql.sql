-- Active: 1770755870172@@127.0.0.1@5432@course_db
-- Создание базы данных (выполняется отдельно от других команд)
-- CREATE DATABASE test_database;

-- Создание таблицы пользователей
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    age INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Создание таблицы заказов
CREATE TABLE IF NOT EXISTS orders (
    order_id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    amount DECIMAL(10, 2),
    status VARCHAR(20) DEFAULT 'pending',
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Вставка тестовых данных в таблицу users
INSERT INTO users (username, email, age) VALUES
('ivassno1ddv', 'ivano1ssddv@example.com', 25),
('john_doe', 'john@example.com', 30),        -- Добавляем user_id=2
('jane_smith', 'jane@example.com', 28);    

-- Вставка тестовых данных в таблицу orders
INSERT INTO orders (user_id, amount, status) VALUES
(1, 1500.50, 'completed'),
(2, 750.25, 'pending'),
(1, 2300.00, 'shipped'),
(3, 500.00, 'completed');

CREATE ROLE app1 LOGIN PASSWORD 'app_pass';
CREATE ROLE readonly LOGIN PASSWORD 'readonly_pass';

GRANT CONNECT ON DATABASE course_db TO app1, readonly;

GRANT USAGE ON SCHEMA public TO app1, readonly;

GRANT SELECT, INSERT, UPDATE, DELETE
ON ALL TABLES IN SCHEMA public TO app1;

GRANT SELECT
ON ALL TABLES IN SCHEMA public TO readonly;


-- Дать права USAGE и SELECT на ВСЕ последовательности в схеме public
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app1;


