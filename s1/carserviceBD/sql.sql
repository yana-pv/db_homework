-- Database: carservice
CREATE TYPE employee_status AS ENUM ('работает', 'уволен', 'отпуск');
CREATE TYPE supplier_order_status AS ENUM ('формируется', 'отправлен', 'доставлен', 'отменен');
CREATE TYPE order_priority AS ENUM ('низкий', 'обычный', 'высокий', 'срочный');
CREATE TYPE order_status AS ENUM ('создан', 'в работе', 'выполнен', 'отменен');

CREATE TABLE car_model (
  id serial PRIMARY KEY,
  model_name varchar(50) NOT NULL,
  brand_name varchar(50) NOT NULL
);

CREATE TABLE car (
  id serial PRIMARY KEY,
  vin varchar(17) NOT NULL UNIQUE,
  year integer NOT NULL CHECK (year >= 1990 AND year <= EXTRACT(year FROM CURRENT_DATE)),
  license_plate varchar(15),
  color varchar(30),
  model_id integer NOT NULL REFERENCES car_model(id)
);

CREATE TABLE client (
  id serial PRIMARY KEY,
  full_name varchar(100) NOT NULL,
  phone_number varchar(12) NOT NULL CHECK (phone_number ~ '^\+7[0-9]{10}$'),
  email varchar(100),
  driver_license varchar(20) UNIQUE
);

CREATE TABLE car_client (
  car_id integer NOT NULL REFERENCES car(id),
  client_id integer NOT NULL REFERENCES client(id),
  PRIMARY KEY (car_id, client_id)
);

CREATE TABLE location (
  id serial PRIMARY KEY,
  address varchar(200) NOT NULL,
  phone_number varchar(12) NOT NULL CHECK (phone_number ~ '^\+7[0-9]{10}$'),
  working_hours varchar(50) NOT NULL
);

CREATE TABLE employee (
  id serial PRIMARY KEY,
  position varchar(50) NOT NULL,
  location_id integer NOT NULL REFERENCES location(id),
  status employee_status NOT NULL,
  full_name varchar(100) NOT NULL,
  phone_number varchar(12) NOT NULL CHECK (phone_number ~ '^\+7[0-9]{10}$'),
  hire_date date NOT NULL
);

CREATE TABLE shift_schedule (
  id serial PRIMARY KEY,
  location_id integer NOT NULL REFERENCES location(id),
  shift_date date NOT NULL,
  start_time time NOT NULL,
  end_time time NOT NULL
);

CREATE TABLE employee_shift_schedule (
  id serial PRIMARY KEY,
  shift_schedule_id integer NOT NULL REFERENCES shift_schedule(id),
  employee_id integer NOT NULL REFERENCES employee(id),
  UNIQUE (shift_schedule_id, employee_id)
);

CREATE TABLE loyalty_card (
  card_number serial PRIMARY KEY,
  id_client integer NOT NULL UNIQUE REFERENCES client(id),
  registration_date date DEFAULT CURRENT_DATE NOT NULL,
  last_visit_date date,
  points_balance integer DEFAULT 0 NOT NULL
);

CREATE TABLE loyalty_rules (
  min_points integer PRIMARY KEY,
  discount_percent numeric(5,2) NOT NULL CHECK (discount_percent BETWEEN 0 AND 100),
  level_name varchar(50) NOT NULL UNIQUE
);

CREATE TABLE supplier (
  id serial PRIMARY KEY,
  company_name varchar(200) NOT NULL,
  phone_number varchar(12) NOT NULL CHECK (phone_number ~ '^\+7[0-9]{10}$'),
  email varchar(100),
  bank_account varchar(20) NOT NULL
);

CREATE TABLE nomenclature (
  article varchar(30) PRIMARY KEY,
  name varchar(200) NOT NULL,
  id_supplier integer NOT NULL REFERENCES supplier(id)
);

CREATE TABLE product_prices (
  id serial PRIMARY KEY,
  article varchar(30) NOT NULL REFERENCES nomenclature(article),
  price integer NOT NULL CHECK (price > 0),
  effective_date date DEFAULT CURRENT_DATE NOT NULL,
  UNIQUE (article, effective_date)
);

CREATE TABLE remains_of_goods (
  id serial PRIMARY KEY,
  location_id integer NOT NULL REFERENCES location(id),
  article varchar(30) NOT NULL REFERENCES nomenclature(article),
  quantity integer NOT NULL CHECK (quantity >= 0),
  UNIQUE (location_id, article)
);

CREATE TABLE order_to_supplier (
  id serial PRIMARY KEY,
  id_supplier integer NOT NULL REFERENCES supplier(id),
  id_location integer NOT NULL REFERENCES location(id),
  total_cost integer CHECK (total_cost >= 0),
  status supplier_order_status DEFAULT 'формируется' NOT NULL,
  created_date timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
  expected_delivery_date date
);

CREATE TABLE supplier_order_items (
  id serial PRIMARY KEY,
  id_order integer NOT NULL REFERENCES order_to_supplier(id),
  article varchar(30) NOT NULL REFERENCES nomenclature(article),
  quantity integer NOT NULL CHECK (quantity > 0),
  unit_price integer NOT NULL CHECK (unit_price > 0),
  total_price integer GENERATED ALWAYS AS (quantity * unit_price) STORED
);

CREATE TABLE service (
  name varchar(100) PRIMARY KEY,
  base_price integer NOT NULL CHECK (base_price > 0),
  lead_time integer NOT NULL CHECK (lead_time > 0)
);

CREATE TABLE service_prices (
  id serial PRIMARY KEY,
  service_name varchar(100) NOT NULL REFERENCES service(name),
  price integer NOT NULL CHECK (price > 0),
  effective_date date DEFAULT CURRENT_DATE NOT NULL,
  UNIQUE (service_name, effective_date)
);

CREATE TABLE client_order (
  id serial PRIMARY KEY,
  id_client integer NOT NULL REFERENCES client(id),
  id_car integer NOT NULL REFERENCES car(id),
  id_location integer NOT NULL REFERENCES location(id),
  employee_id integer NOT NULL REFERENCES employee(id),
  created_date timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
  total_amount integer NOT NULL DEFAULT 0 CHECK (total_amount >= 0),
  status order_status DEFAULT 'создан' NOT NULL,
  completion_date timestamp,
  notes text,
  priority order_priority DEFAULT 'обычный' NOT NULL,
  CHECK (completion_date IS NULL OR completion_date >= created_date)
);

CREATE TABLE client_order_items (
  id serial PRIMARY KEY,
  id_order integer NOT NULL REFERENCES client_order(id),
  product_price_id integer NOT NULL REFERENCES product_prices(id),
  quantity integer NOT NULL CHECK (quantity > 0),
  unit_price integer NOT NULL CHECK (unit_price > 0),
  total_price integer GENERATED ALWAYS AS (quantity * unit_price) STORED
);

CREATE TABLE client_order_services (
  id serial PRIMARY KEY,
  id_order integer NOT NULL REFERENCES client_order(id),
  service_price_id integer NOT NULL REFERENCES service_prices(id),
  quantity integer NOT NULL DEFAULT 1 CHECK (quantity > 0),
  unit_price integer NOT NULL CHECK (unit_price > 0),
  total_price integer GENERATED ALWAYS AS (quantity * unit_price) STORED
);

CREATE TABLE client_order_status_log (
    id SERIAL PRIMARY KEY, 
    order_id INTEGER NOT NULL, 
    status order_status NOT NULL,
    FOREIGN KEY (order_id) REFERENCES client_order(id)
);


-- Добавление данных в таблицы
INSERT INTO client (full_name, phone_number, email, driver_license) VALUES 
('Белова Анастасия Петровна', '+79164445566', 'belovaanastasiya@gmail.com', '71СС453423'), 
('Соколов Роман Дмитриевич', '+79168889900', 'sokolov95@yandex.ru', '77KK345118');

UPDATE public.loyalty_card
SET id_client=3, registration_date='2023-03-10', last_visit_date='2024-01-08', points_balance=800
WHERE card_number=1003;

-- Добавляем заказы с разными статусами для одних и тех же клиентов
INSERT INTO client_order (id_client, id_car, id_location, employee_id, total_amount, status, created_date, completion_date, priority) VALUES
(1, 1, 1, 1, 300000, 'выполнен', '2024-01-05 10:00:00', '2024-01-05 16:00:00', 'обычный'),
(1, 1, 1, 1, 150000, 'в работе', '2024-01-15 09:30:00', NULL, 'обычный'),
(1, 1, 1, 1, 200000, 'отменен', '2024-01-10 14:20:00', NULL, 'обычный');

INSERT INTO client_order (id_client, id_car, id_location, employee_id, total_amount, status, created_date, completion_date, priority) VALUES
(2, 2, 1, 1, 250000, 'выполнен', '2024-01-06 11:00:00', '2024-01-06 17:00:00', 'высокий'),
(2, 2, 1, 1, 180000, 'в работе', '2024-01-16 10:15:00', NULL, 'обычный'),
(2, 2, 1, 1, 120000, 'отменен', '2024-01-12 15:45:00', NULL, 'низкий');
INSERT INTO client_order (id_client, id_car, id_location, employee_id, total_amount, status, created_date, completion_date, priority) VALUES
(3, 3, 2, 4, 400000, 'выполнен', '2024-01-07 12:30:00', '2024-01-07 18:00:00', 'обычный'),
(3, 3, 2, 4, 220000, 'в работе', '2024-01-17 11:20:00', NULL, 'обычный');

INSERT INTO client_order (id_client, id_car, id_location, employee_id, total_amount, status, created_date, completion_date, priority) VALUES
(4, 4, 1, 1, 150000, 'выполнен', '2024-01-08 13:15:00', '2024-01-08 15:30:00', 'низкий');

INSERT INTO client_order (id_client, id_car, id_location, employee_id, total_amount, status, created_date, completion_date, priority) VALUES
(5, 5, 2, 4, 350000, 'выполнен', '2024-01-09 08:45:00', '2024-01-09 14:20:00', 'срочный'),
(5, 5, 2, 4, 280000, 'в работе', '2024-01-18 13:10:00', NULL, 'обычный'),
(5, 5, 2, 4, 190000, 'отменен', '2024-01-14 16:30:00', NULL, 'высокий');

-- Добавляем второй заказ для Иванова (id_client = 1, id_car = 1)
INSERT INTO client_order (
    id_client, id_car, id_location, employee_id, 
    total_amount, status, created_date, completion_date, 
    notes, priority
) VALUES
(1, 1, 1, 1, 320000, 'выполнен', '2024-02-15 10:00:00', '2024-02-15 13:00:00', 'Замена масла и фильтра', 'обычный'),
(1, 1, 1, 1, 180000, 'выполнен', '2024-03-10 09:15:00', '2024-03-10 11:00:00', 'Диагностика + лампы', 'низкий');

-- Добавляем второй заказ для Сидорова (id_client = 5, id_car = 5)
INSERT INTO client_order (
    id_client, id_car, id_location, employee_id, 
    total_amount, status, created_date, completion_date, 
    notes, priority
) VALUES
(5, 5, 2, 4, 450000, 'выполнен', '2024-02-20 14:00:00', '2024-02-20 16:30:00', 'Замена тормозных колодок', 'обычный');




SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public';




-- Заполнение таблицы car_model
INSERT INTO car_model (model_name, brand_name) VALUES
('Camry', 'Toyota'),
('Corolla', 'Toyota'),
('Civic', 'Honda'),
('Accord', 'Honda'),
('X5', 'BMW'),
('3 Series', 'BMW'),
('Focus', 'Ford'),
('Mondeo', 'Ford'),
('Logan', 'Renault'),
('Sandero', 'Renault');

-- Заполнение таблицы car
INSERT INTO car (vin, year, license_plate, color, model_id) VALUES
('JTDKN3DU4A1234567', 2020, 'А123ВС777', 'Черный', 1),
('2HGES165X8H543210', 2018, 'Е456КХ777', 'Белый', 3),
('WBAFR7C56BC654321', 2021, 'О789ТТ777', 'Синий', 5),
('VF1LCD10345678901', 2019, 'У321ММ777', 'Красный', 9),
('ZCFC75F2005678901', 2022, 'Р555АА777', 'Серый', 2),
('1G1ZB5ST6GF123456', 2017, 'Х987НН777', 'Зеленый', 7),
('JM1BL1SF8A1234987', 2020, 'С111СС777', 'Черный', 4),
('WVWZZZ1KZ8W345678', 2018, 'М222ММ777', 'Белый', 6),
('VF3WC9FPC12345678', 2021, 'К333КК777', 'Серебристый', 10),
('TMBJJ7NP3B3456789', 2019, 'В444ВВ777', 'Синий', 8);

-- Заполнение таблицы client
INSERT INTO client (full_name, phone_number, email, driver_license) VALUES
('Иванов Петр Сергеевич', '+79161234567', 'ivanov@mail.ru', '77АВ123456'),
('Смирнова Анна Владимировна', '+79162345678', 'smirnova@gmail.com', '77ВС654321'),
('Петров Алексей Иванович', '+79163456789', 'petrov@yandex.ru', '77ЕК789012'),
('Козлова Мария Дмитриевна', '+79164567890', 'kozlova@mail.ru', '77ММ345678'),
('Сидоров Дмитрий Петрович', '+79165678901', 'sidorov@gmail.com', '77НН901234'),
('Федорова Елена Александровна', '+79166789012', 'fedorova@yandex.ru', '77ОО567890'),
('Николаев Сергей Викторович', '+79167890123', 'nikolaev@mail.ru', '77РР123789'),
('Орлова Ольга Игоревна', '+79168901234', 'orlova@gmail.com', '77СС456123'),
('Васильев Андрей Николаевич', '+79169012345', 'vasilev@yandex.ru', '77ТТ789456'),
('Павлова Ирина Сергеевна', '+79160123456', 'pavlova@mail.ru', '77УУ321654');

-- Заполнение таблицы car_client
INSERT INTO car_client (car_id, client_id) VALUES
(1, 1), (2, 2), (3, 3), (4, 4), (5, 5),
(6, 6), (7, 7), (8, 8), (9, 9), (10, 10);

-- Заполнение таблицы location
INSERT INTO location (address, phone_number, working_hours) VALUES
('ул. Ленина, 25, Москва', '+74951234567', '09:00-21:00'),
('пр. Мира, 15, Санкт-Петербург', '+78122456789', '08:00-20:00'),
('ул. Гагарина, 8, Казань', '+78432567890', '09:00-19:00'),
('ул. Кирова, 33, Екатеринбург', '+73436789012', '08:00-20:00'),
('пр. Победы, 12, Новосибирск', '+73834567890', '09:00-21:00');

-- Заполнение таблицы employee
INSERT INTO employee (position, location_id, status, full_name, phone_number, hire_date) VALUES
('Менеджер', 1, 'работает', 'Семенов Артем Владимирович', '+79161112233', '2020-03-15'),
('Механик', 1, 'работает', 'Григорьев Максим Олегович', '+79162223344', '2019-07-20'),
('Автослесарь', 1, 'отпуск', 'Тарасов Иван Сергеевич', '+79163334455', '2021-05-10'),
('Менеджер', 2, 'работает', 'Белова Анастасия Петровна', '+79164445566', '2020-11-03'),
('Механик', 2, 'работает', 'Киселев Денис Андреевич', '+79165556677', '2018-09-12'),
('Автослесарь', 2, 'работает', 'Морозов Павел Викторович', '+79166667788', '2022-01-25'),
('Менеджер', 3, 'работает', 'Зайцева Виктория Игоревна', '+79167778899', '2021-08-14'),
('Механик', 3, 'уволен', 'Соколов Роман Дмитриевич', '+79168889900', '2019-04-30'),
('Автослесарь', 3, 'работает', 'Волков Александр Николаевич', '+79169990011', '2020-12-01'),
('Менеджер', 4, 'работает', 'Лебедева Марина Алексеевна', '+79161001122', '2022-03-20');

-- Заполнение таблицы shift_schedule
INSERT INTO shift_schedule (location_id, shift_date, start_time, end_time) VALUES
(1, '2024-01-15', '09:00', '18:00'),
(1, '2024-01-15', '12:00', '21:00'),
(2, '2024-01-15', '08:00', '17:00'),
(1, '2024-01-16', '09:00', '18:00'),
(2, '2024-01-16', '08:00', '17:00');

-- Заполнение таблицы employee_shift_schedule
INSERT INTO employee_shift_schedule (shift_schedule_id, employee_id) VALUES
(1, 1), (1, 2), (2, 3), (3, 4), (3, 5),
(4, 1), (4, 2), (5, 4), (5, 6);

-- Заполнение таблицы loyalty_card
INSERT INTO loyalty_card (card_number, id_client, registration_date, last_visit_date, points_balance) VALUES
(1001, 1, '2023-01-15', '2024-01-10', 1500),
(1002, 2, '2023-02-20', '2024-01-12', 800),
(1003, 3, '2023-03-10', '2024-01-08', 2500),
(1004, 4, '2023-04-05', '2023-12-20', 300),
(1005, 5, '2023-05-12', '2024-01-05', 1200),
(1006, 6, '2023-06-18', '2024-01-11', 600),
(1007, 7, '2023-07-22', '2023-11-15', 1800),
(1008, 8, '2023-08-30', '2024-01-09', 900),
(1009, 9, '2023-09-14', '2024-01-07', 2100),
(1010, 10, '2023-10-25', '2024-01-13', 400);

-- Заполнение таблицы loyalty_rules
INSERT INTO loyalty_rules (min_points, discount_percent, level_name) VALUES
(0, 0.00, 'Новичок'),
(500, 5.00, 'Бронза'),
(1000, 7.50, 'Серебро'),
(2000, 10.00, 'Золото'),
(5000, 15.00, 'Платина');

-- Заполнение таблицы supplier
INSERT INTO supplier (company_name, phone_number, email, bank_account) VALUES
('АвтоДеталь Трейд', '+79167778899', 'info@avtodetal.ru', '40702810500000001234'),
('Масла и Фильтры ООО', '+79168889900', 'sales@masla-filtry.ru', '40702810600000005678'),
('Шиномонтаж Сервис', '+79169990011', 'office@shinamontag.ru', '40702810700000009012'),
('Автоэлектрика Лтд', '+79161001122', 'order@avtoelectro.ru', '40702810800000003456'),
('Кузовные детали ИП', '+79161112233', 'kp@kuzovdetali.ru', '40702810900000007890');

-- Заполнение таблицы nomenclature
INSERT INTO nomenclature (article, name, id_supplier) VALUES
('FILT12345', 'Масляный фильтр Toyota', 2),
('OIL56789', 'Моторное масло 5W-30 4л', 2),
('BRAKE987', 'Тормозные колодки передние', 1),
('SPARK456', 'Свечи зажигания NGK', 4),
('BATT7890', 'Аккумулятор 60Ач', 4),
('TIRE1234', 'Летняя шина 205/55 R16', 3),
('TIRE5678', 'Зимняя шина 205/55 R16', 3),
('OIL32165', 'Трансмиссионное масло 75W-90', 2),
('FILT9876', 'Воздушный фильтр', 2),
('LAMP4567', 'Лампа ближнего света H7', 4);

-- Заполнение таблицы product_prices
INSERT INTO product_prices (article, price, effective_date) VALUES
('FILT12345', 120000, '2024-01-01'),
('OIL56789', 250000, '2024-01-01'),
('BRAKE987', 450000, '2024-01-01'),
('SPARK456', 80000, '2024-01-01'),
('BATT7890', 550000, '2024-01-01'),
('TIRE1234', 400000, '2024-01-01'),
('TIRE5678', 480000, '2024-01-01'),
('OIL32165', 180000, '2024-01-01'),
('FILT9876', 90000, '2024-01-01'),
('LAMP4567', 60000, '2024-01-01');

-- Заполнение таблицы remains_of_goods
INSERT INTO remains_of_goods (location_id, article, quantity) VALUES
(1, 'FILT12345', 15),
(1, 'OIL56789', 8),
(1, 'BRAKE987', 5),
(1, 'SPARK456', 20),
(2, 'FILT12345', 10),
(2, 'OIL56789', 12),
(2, 'BATT7890', 3),
(2, 'TIRE1234', 8),
(3, 'OIL56789', 6),
(3, 'TIRE5678', 4);

-- Заполнение таблицы order_to_supplier
INSERT INTO order_to_supplier (id_supplier, id_location, total_cost, status, created_date, expected_delivery_date) VALUES
(1, 1, 1500000, 'доставлен', '2024-01-05 10:00:00', '2024-01-10'),
(2, 1, 800000, 'отправлен', '2024-01-10 14:30:00', '2024-01-17'),
(3, 2, 3200000, 'формируется', '2024-01-12 09:15:00', '2024-01-20'),
(4, 3, 450000, 'доставлен', '2024-01-08 11:20:00', '2024-01-12'),
(2, 2, 1200000, 'отправлен', '2024-01-11 16:45:00', '2024-01-18');

-- Заполнение таблицы supplier_order_items
INSERT INTO supplier_order_items (id_order, article, quantity, unit_price) VALUES
(1, 'BRAKE987', 3, 450000),
(1, 'SPARK456', 10, 80000),
(2, 'OIL56789', 3, 250000),
(2, 'FILT12345', 5, 120000),
(3, 'TIRE1234', 8, 400000),
(4, 'LAMP4567', 5, 60000),
(4, 'SPARK456', 3, 80000),
(5, 'OIL56789', 4, 250000),
(5, 'FILT9876', 10, 90000);

-- Заполнение таблицы service
INSERT INTO service (name, base_price, lead_time) VALUES
('Замена масла', 50000, 1),
('Замена фильтров', 30000, 1),
('Замена тормозных колодок', 80000, 2),
('Замена свечей зажигания', 25000, 1),
('Замена аккумулятора', 15000, 1),
('Шиномонтаж', 40000, 2),
('Развал-схождение', 60000, 2),
('Диагностика двигателя', 35000, 1),
('Замена ламп', 10000, 1),
('Полное ТО', 120000, 3);

-- Заполнение таблицы service_prices
INSERT INTO service_prices (service_name, price, effective_date) VALUES
('Замена масла', 50000, '2024-01-01'),
('Замена фильтров', 30000, '2024-01-01'),
('Замена тормозных колодок', 80000, '2024-01-01'),
('Замена свечей зажигания', 25000, '2024-01-01'),
('Замена аккумулятора', 15000, '2024-01-01'),
('Шиномонтаж', 40000, '2024-01-01'),
('Развал-схождение', 60000, '2024-01-01'),
('Диагностика двигателя', 35000, '2024-01-01'),
('Замена ламп', 10000, '2024-01-01'),
('Полное ТО', 120000, '2024-01-01');

-- Заполнение таблицы client_order
INSERT INTO client_order (id_client, id_car, id_location, employee_id, total_amount, status, created_date, completion_date, notes, priority) VALUES
(1, 1, 1, 1, 420000, 'выполнен', '2024-01-10 09:30:00', '2024-01-10 14:00:00', 'Клиент просил проверить тормозную систему', 'обычный'),
(2, 2, 1, 1, 300000, 'в работе', '2024-01-12 10:15:00', NULL, 'Срочная замена масла', 'высокий'),
(3, 3, 2, 4, 850000, 'создан', '2024-01-13 11:20:00', NULL, 'Полное ТО + замена фильтров', 'обычный'),
(4, 4, 1, 1, 150000, 'выполнен', '2024-01-08 14:45:00', '2024-01-08 16:30:00', 'Замена лампы ближнего света', 'низкий'),
(5, 5, 2, 4, 600000, 'в работе', '2024-01-14 08:30:00', NULL, 'Шиномонтаж + развал-схождение', 'обычный');

-- Заполнение таблицы client_order_items
INSERT INTO client_order_items (id_order, product_price_id, quantity, unit_price) VALUES
(1, 1, 1, 120000),  -- Масляный фильтр
(1, 2, 1, 250000),  -- Моторное масло
(2, 2, 1, 250000),  -- Моторное масло
(3, 1, 1, 120000),  -- Масляный фильтр
(3, 9, 1, 90000),   -- Воздушный фильтр
(4, 10, 1, 60000),  -- Лампа
(5, 6, 4, 400000);  -- Летние шины

-- Заполнение таблицы client_order_services
INSERT INTO client_order_services (id_order, service_price_id, quantity, unit_price) VALUES
(1, 1, 1, 50000),   -- Замена масла
(2, 1, 1, 50000),   -- Замена масла
(3, 10, 1, 120000), -- Полное ТО
(3, 2, 1, 30000),   -- Замена фильтров
(4, 9, 1, 10000),   -- Замена ламп
(5, 6, 1, 40000),   -- Шиномонтаж
(5, 7, 1, 60000);   -- Развал-схождение




-- Добавление данных в таблицы
INSERT INTO client (full_name, phone_number, email, driver_license) VALUES 
('Белова Анастасия Петровна', '+79164445566', 'belovaanastasiya@gmail.com', '71СС453423'), 
('Соколов Роман Дмитриевич', '+79168889900', 'sokolov95@yandex.ru', '77KK345118');

UPDATE public.loyalty_card
SET id_client=3, registration_date='2023-03-10', last_visit_date='2024-01-08', points_balance=800
WHERE card_number=1003;

-- Добавляем заказы с разными статусами для одних и тех же клиентов
INSERT INTO client_order (id_client, id_car, id_location, employee_id, total_amount, status, created_date, completion_date, priority) VALUES
(1, 1, 1, 1, 300000, 'выполнен', '2024-01-05 10:00:00', '2024-01-05 16:00:00', 'обычный'),
(1, 1, 1, 1, 150000, 'в работе', '2024-01-15 09:30:00', NULL, 'обычный'),
(1, 1, 1, 1, 200000, 'отменен', '2024-01-10 14:20:00', NULL, 'обычный');

INSERT INTO client_order (id_client, id_car, id_location, employee_id, total_amount, status, created_date, completion_date, priority) VALUES
(2, 2, 1, 1, 250000, 'выполнен', '2024-01-06 11:00:00', '2024-01-06 17:00:00', 'высокий'),
(2, 2, 1, 1, 180000, 'в работе', '2024-01-16 10:15:00', NULL, 'обычный'),
(2, 2, 1, 1, 120000, 'отменен', '2024-01-12 15:45:00', NULL, 'низкий');
INSERT INTO client_order (id_client, id_car, id_location, employee_id, total_amount, status, created_date, completion_date, priority) VALUES
(3, 3, 2, 4, 400000, 'выполнен', '2024-01-07 12:30:00', '2024-01-07 18:00:00', 'обычный'),
(3, 3, 2, 4, 220000, 'в работе', '2024-01-17 11:20:00', NULL, 'обычный');

INSERT INTO client_order (id_client, id_car, id_location, employee_id, total_amount, status, created_date, completion_date, priority) VALUES
(4, 4, 1, 1, 150000, 'выполнен', '2024-01-08 13:15:00', '2024-01-08 15:30:00', 'низкий');

INSERT INTO client_order (id_client, id_car, id_location, employee_id, total_amount, status, created_date, completion_date, priority) VALUES
(5, 5, 2, 4, 350000, 'выполнен', '2024-01-09 08:45:00', '2024-01-09 14:20:00', 'срочный'),
(5, 5, 2, 4, 280000, 'в работе', '2024-01-18 13:10:00', NULL, 'обычный'),
(5, 5, 2, 4, 190000, 'отменен', '2024-01-14 16:30:00', NULL, 'высокий');

-- Добавляем второй заказ для Иванова (id_client = 1, id_car = 1)
INSERT INTO client_order (
    id_client, id_car, id_location, employee_id, 
    total_amount, status, created_date, completion_date, 
    notes, priority
) VALUES
(1, 1, 1, 1, 320000, 'выполнен', '2024-02-15 10:00:00', '2024-02-15 13:00:00', 'Замена масла и фильтра', 'обычный'),
(1, 1, 1, 1, 180000, 'выполнен', '2024-03-10 09:15:00', '2024-03-10 11:00:00', 'Диагностика + лампы', 'низкий');

-- Добавляем второй заказ для Сидорова (id_client = 5, id_car = 5)
INSERT INTO client_order (
    id_client, id_car, id_location, employee_id, 
    total_amount, status, created_date, completion_date, 
    notes, priority
) VALUES
(5, 5, 2, 4, 450000, 'выполнен', '2024-02-20 14:00:00', '2024-02-20 16:30:00', 'Замена тормозных колодок', 'обычный');




--select_join_queries.md
--1.1
SELECT *
FROM employee;

--2.2
SELECT full_name, phone_number
FROM client;

--4.1
SELECT id, total_amount, total_amount * 1.2 AS "Цена с НДС"
FROM client_order;

--5.2
SELECT 
    id,
    full_name,
    hire_date,
    ROUND((CURRENT_DATE - hire_date) / 365.25, 2) AS "Стаж (лет с точностью до сотых)"
FROM employee;

--7.1
SELECT car_model.brand_name, car_model.model_name, car.color
FROM car JOIN car_model 
ON car.model_id = car_model.id
WHERE car.color = 'Черный';

--8.2
SELECT id, total_amount, priority, status
FROM client_order
WHERE total_amount > 500000 OR priority IN ('высокий', 'срочный');

--10.1
SELECT id, priority, created_date, status
FROM client_order
ORDER BY CASE
WHEN priority = 'срочный' THEN 1
WHEN priority = 'высокий' THEN 2
WHEN priority = 'обычный' THEN 3
WHEN priority = 'низкий' THEN 4
END;

--11.2
SELECT name, base_price
FROM service
WHERE name LIKE 'Замен%';

--13.1
SELECT id, company_name, bank_account
FROM supplier
LIMIT 4 OFFSET 1; 

--14.2
SELECT full_name AS "ФИО сотрудника", 
	shift_date AS "Рабочий день", 
	start_time AS "Начало смены", 
	end_time AS "Окончание смены",
	l.address AS "Место работы"
FROM employee 
INNER JOIN employee_shift_schedule ess ON employee.id = ess.employee_id
INNER JOIN shift_schedule ss ON ess.shift_schedule_id = ss.id
INNER JOIN location l ON ss.location_id = l.id;

--16.1
SELECT card_number, full_name, points_balance
FROM client
RIGHT JOIN loyalty_card 
ON client.id = loyalty_card.id_client;

--17.2
SELECT company_name AS "Поставщик",
    address AS "Место назначения",
    supplier.phone_number AS "Телефон поставщика",
    location.phone_number AS "Телефон автосервиса"
FROM supplier
CROSS JOIN location;




-- aggregate_group_queries.md
-- 1.1
SELECT COUNT(*) as number_of_completed_orders
FROM client_order
WHERE status = 'выполнен';

--2.2
SELECT SUM(total_cost) AS total_supplier_orders_cost
FROM order_to_supplier os
INNER JOIN location l ON os.id_location = l.id
WHERE address = 'ул. Ленина, 25, Москва';

--4.1
SELECT MIN(registration_date) AS earliest_registration
FROM loyalty_card;

--5.2
SELECT MAX(points_balance) AS max_points
FROM loyalty_card;

--7.1
SELECT 
    COUNT(*) AS orders_count,
    SUM(total_amount) AS total_sum,
    ROUND(AVG(total_amount), 2) AS average_amount,
    MIN(total_amount) AS min_amount,
    MAX(total_amount) AS max_amount
FROM client_order;

--8.2
SELECT priority, COUNT(*) AS orders_count
FROM client_order
GROUP BY priority;

--10.1
SELECT position, status, COUNT(*) AS employees_count
FROM employee
GROUP BY
	GROUPING SETS ((position, status), (position), (status), ())
ORDER BY position, status;

--11.2
SELECT brand_name, model_name, COUNT(*) AS cars_count
FROM car c
INNER JOIN car_model cm ON c.model_id = cm.id
GROUP BY ROLLUP (brand_name, model_name)
ORDER BY brand_name, model_name;




-- sub_queries.md
--1.1
SELECT (SELECT MIN(created_date) FROM client_order) AS first_order_date;

--2.1
SELECT full_name, order_count
FROM (
    SELECT c.full_name, COUNT(co.id) AS order_count
    FROM client c
    LEFT JOIN client_order co ON c.id = co.id_client
    GROUP BY c.full_name
) 
WHERE order_count > 0;

--3.1
SELECT *
FROM client_order
WHERE total_amount > (
    SELECT AVG(total_amount) 
    FROM client_order 
    WHERE status = 'выполнен'
);

--4.1
SELECT n.article, n.name as product_name, SUM(coi.quantity) as total_sold
FROM client_order_items coi
INNER JOIN product_prices pp ON coi.product_price_id = pp.id
INNER JOIN nomenclature n ON pp.article = n.article 
GROUP BY n.article
HAVING SUM(coi.quantity) > (SELECT AVG(quantity) FROM client_order_items);

--5.1
SELECT DISTINCT name 
FROM nomenclature
WHERE article <> ALL (
    SELECT DISTINCT article 
    FROM client_order_items coi 
    INNER JOIN product_prices pp ON coi.product_price_id = pp.id
);

--6.1
SELECT *
FROM nomenclature
WHERE article IN (
    SELECT article 
    FROM remains_of_goods 
    WHERE quantity > 10
    AND location_id IN (
        SELECT id 
        FROM location 
        WHERE address LIKE '%Москва%'
    )
);

--7.1
SELECT name, base_price
FROM service
WHERE name = ANY (
    SELECT service_name 
    FROM client_order_services cos 
    INNER JOIN service_prices sp ON cos.service_price_id = sp.id
);

--8.1
SELECT *
FROM client c
WHERE EXISTS (
    SELECT 1 
    FROM loyalty_card lc 
    WHERE lc.id_client = c.id 
    AND lc.points_balance > 1000
);

--9.1
SELECT full_name, registration_date, points_balance
FROM client 
INNER JOIN loyalty_card ON client.id = loyalty_card.id_client
WHERE (registration_date, points_balance) IN (
    SELECT registration_date, points_balance
    FROM loyalty_card lc
    INNER JOIN loyalty_rules lr ON lc.points_balance >= lr.min_points
    WHERE level_name = 'Золото'
);

--10.1
SELECT 
    address,
    (SELECT COUNT(*) 
     FROM employee e 
     WHERE e.location_id = l.id AND e.status = 'работает') 
	 AS active_employees
FROM location l;

--10.4
SELECT 
    n.article,
    n.name,
    (SELECT price 
     FROM product_prices pp 
     WHERE pp.article = n.article 
     ORDER BY effective_date DESC 
     LIMIT 1) 
	 AS current_price
FROM nomenclature n;




-- Очистка данных в правильном порядке (с учетом внешних ключей)
-- TRUNCATE TABLE 
--     client_order_services,
--     client_order_items,
--     supplier_order_items,
--     client_order,
--     order_to_supplier,
--     employee_shift_schedule,
--     shift_schedule,
--     loyalty_card,
--     remains_of_goods,
--     product_prices,
--     service_prices,
--     car_client,
--     employee,
--     location,
--     car,
--     client,
--     nomenclature,
--     supplier,
--     car_model,
--     loyalty_rules,
--     service
-- RESTART IDENTITY CASCADE;

-- Добавление данных в таблицы
INSERT INTO client (full_name, phone_number, email, driver_license) VALUES 
('Белова Анастасия Петровна', '+79164445566', 'belovaanastasiya@gmail.com', '71СС453423'), 
('Соколов Роман Дмитриевич', '+79168889900', 'sokolov95@yandex.ru', '77KK345118');

UPDATE public.loyalty_card
SET id_client=3, registration_date='2023-03-10', last_visit_date='2024-01-08', points_balance=800
WHERE card_number=1003;

-- Добавляем заказы с разными статусами для одних и тех же клиентов
INSERT INTO client_order (id_client, id_car, id_location, employee_id, total_amount, status, created_date, completion_date, priority) VALUES
(1, 1, 1, 1, 300000, 'выполнен', '2024-01-05 10:00:00', '2024-01-05 16:00:00', 'обычный'),
(1, 1, 1, 1, 150000, 'в работе', '2024-01-15 09:30:00', NULL, 'обычный'),
(1, 1, 1, 1, 200000, 'отменен', '2024-01-10 14:20:00', NULL, 'обычный');

INSERT INTO client_order (id_client, id_car, id_location, employee_id, total_amount, status, created_date, completion_date, priority) VALUES
(2, 2, 1, 1, 250000, 'выполнен', '2024-01-06 11:00:00', '2024-01-06 17:00:00', 'высокий'),
(2, 2, 1, 1, 180000, 'в работе', '2024-01-16 10:15:00', NULL, 'обычный'),
(2, 2, 1, 1, 120000, 'отменен', '2024-01-12 15:45:00', NULL, 'низкий');
INSERT INTO client_order (id_client, id_car, id_location, employee_id, total_amount, status, created_date, completion_date, priority) VALUES
(3, 3, 2, 4, 400000, 'выполнен', '2024-01-07 12:30:00', '2024-01-07 18:00:00', 'обычный'),
(3, 3, 2, 4, 220000, 'в работе', '2024-01-17 11:20:00', NULL, 'обычный');

INSERT INTO client_order (id_client, id_car, id_location, employee_id, total_amount, status, created_date, completion_date, priority) VALUES
(4, 4, 1, 1, 150000, 'выполнен', '2024-01-08 13:15:00', '2024-01-08 15:30:00', 'низкий');

INSERT INTO client_order (id_client, id_car, id_location, employee_id, total_amount, status, created_date, completion_date, priority) VALUES
(5, 5, 2, 4, 350000, 'выполнен', '2024-01-09 08:45:00', '2024-01-09 14:20:00', 'срочный'),
(5, 5, 2, 4, 280000, 'в работе', '2024-01-18 13:10:00', NULL, 'обычный'),
(5, 5, 2, 4, 190000, 'отменен', '2024-01-14 16:30:00', NULL, 'высокий');

-- Добавляем второй заказ для Иванова (id_client = 1, id_car = 1)
INSERT INTO client_order (
    id_client, id_car, id_location, employee_id, 
    total_amount, status, created_date, completion_date, 
    notes, priority
) VALUES
(1, 1, 1, 1, 320000, 'выполнен', '2024-02-15 10:00:00', '2024-02-15 13:00:00', 'Замена масла и фильтра', 'обычный'),
(1, 1, 1, 1, 180000, 'выполнен', '2024-03-10 09:15:00', '2024-03-10 11:00:00', 'Диагностика + лампы', 'низкий');

-- Добавляем второй заказ для Сидорова (id_client = 5, id_car = 5)
INSERT INTO client_order (
    id_client, id_car, id_location, employee_id, 
    total_amount, status, created_date, completion_date, 
    notes, priority
) VALUES
(5, 5, 2, 4, 450000, 'выполнен', '2024-02-20 14:00:00', '2024-02-20 16:30:00', 'Замена тормозных колодок', 'обычный');




--cte_union_window.md
--1.3 Товары, которые есть в наличии в московском филиале в количестве более 10 штук
WITH MoscowItems AS (
    SELECT article, quantity
    FROM remains_of_goods rog
    INNER JOIN location l ON rog.location_id = l.id
    WHERE l.address LIKE '%Москва%'
)
SELECT n.*, mi.quantity
FROM nomenclature n
INNER JOIN MoscowItems mi ON n.article = mi.article
WHERE mi.quantity > 10;

--2.1 Все заказы (клиентские и поставщикам)
SELECT 
    id as order_number,
    created_date as creation_date,
    total_amount as amount,
    'client' as order_type
FROM client_order
UNION
SELECT 
    id as order_number,
    created_date as creation_date,
    total_cost as amount,
    'supplier' as order_type
FROM order_to_supplier
ORDER BY creation_date DESC;

--3.1 Клиентов, у которых были и выполненные, и активные, и отмененные заказы
SELECT 
    c.full_name
FROM client c
WHERE c.id IN (
    SELECT id_client
    FROM client_order 
    WHERE status = 'выполнен'
    INTERSECT
    SELECT id_client
    FROM client_order 
    WHERE status = 'в работе'
    INTERSECT
    SELECT id_client
    FROM client_order 
    WHERE status = 'отменен'
);

--4.1 Клиенты без лояльной карты
SELECT 
    full_name
FROM client
WHERE id IN (
    SELECT id FROM client
    EXCEPT
    SELECT id_client FROM loyalty_card
);

--5.1 Количество заказов на каждого сотрудника
SELECT 
    co.id AS order_id,
    e.full_name AS employee_name,
    co.total_amount,
    COUNT(*) OVER (PARTITION BY co.employee_id) AS total_orders_by_employee
FROM client_order co
JOIN employee e ON co.employee_id = e.id
ORDER BY e.full_name, co.created_date;

--6.2 Накопительное количество заказов по каждому сотруднику во времени
SELECT 
    e.full_name AS employee_name,
    co.id AS order_id,
    co.created_date,
    COUNT(*) OVER (
        PARTITION BY co.employee_id 
        ORDER BY co.created_date
    ) AS cumulative_orders
FROM client_order co
JOIN employee e ON co.employee_id = e.id;

--8.1 Средняя сумма заказов клиентов, близких по стоимости (±100 000)
SELECT 
    id AS order_id,
    total_amount,
    ROUND(
        AVG(total_amount) OVER (
            ORDER BY total_amount
            RANGE BETWEEN 100000 PRECEDING AND 100000 FOLLOWING
        )
    ) AS avg_amount_in_range
FROM client_order;

--9.2  RANK() — Ранжирование сотрудников по общей сумме выполненных заказов
WITH EmployeeRevenue AS (
    SELECT 
        e.id,
        e.full_name,
        e.position,
        COALESCE(SUM(co.total_amount), 0) AS total_revenue
    FROM employee e
    LEFT JOIN client_order co 
        ON e.id = co.employee_id 
        AND co.status = 'выполнен'
    GROUP BY e.id, e.full_name, e.position
)
SELECT 
    full_name,
    position,
    total_revenue,
    RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank
FROM EmployeeRevenue;

--10.2 Следующий визит клиента и интервал между заказами
SELECT 
    c.full_name AS client_name,
    co.id AS order_id,
    co.created_date AS current_visit,
    LEAD(co.created_date) OVER (
        PARTITION BY co.id_client 
        ORDER BY co.created_date
    ) AS next_visit,
    (
        LEAD(co.created_date) OVER (
            PARTITION BY co.id_client 
            ORDER BY co.created_date
        ) - co.created_date
    ) AS days_until_next
FROM client_order co
JOIN client c ON co.id_client = c.id
WHERE co.status = 'выполнен';




--transaction.md
--- 1.1.2. Добавление товара в заказ клиента и обновление остатков товаров
BEGIN;
-- Добавляем товар в заказ клиента
INSERT INTO client_order_items (id_order, product_price_id, quantity, unit_price) 
VALUES (1, 1, 2, 1500);
-- Обновляем остатки товаров на складе
UPDATE remains_of_goods SET quantity = quantity - 2 
WHERE location_id = 1 AND article = (SELECT article FROM product_prices WHERE id = 1);
COMMIT;


--Восстанавливаем остатки товаров на складе
UPDATE remains_of_goods SET quantity = quantity + 2 
WHERE location_id = 1 AND article = (SELECT article FROM product_prices WHERE id = 1);

-- Удаляем добавленную запись из заказа
DELETE FROM client_order_items 
WHERE id_order = 1 
AND product_price_id = 1 
AND quantity = 2 
AND unit_price = 1500;


--1.2.2. Откат добавления товара в заказ и обновления остатков
BEGIN;
-- Добавляем товар в заказ клиента
INSERT INTO client_order_items (id_order, product_price_id, quantity, unit_price) 
VALUES (1, 1, 2, 1500);
-- Обновляем остатки товаров на складе
UPDATE remains_of_goods SET quantity = quantity - 2 
WHERE location_id = 1 AND article = (SELECT article FROM product_prices WHERE id = 1);
ROLLBACK;

--1.3.2. Ошибка при добавлении товара в заказ и обновлении остатков
BEGIN;
-- Добавляем товар в заказ клиента
INSERT INTO client_order_items (id_order, product_price_id, quantity, unit_price) 
VALUES (1, 1, -5, 1500);  -- Ошибка: CHECK (quantity > 0)
-- Обновляем остатки товаров на складе (этот код не выполнился)
UPDATE remains_of_goods SET quantity = quantity - 2 
WHERE location_id = 1 AND article = (SELECT article FROM product_prices WHERE id = 1);
COMMIT;

--2.3.2.
-- T1: Делает SELECT на количество клиентов с email @mail.ru - 4
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT COUNT(*) FROM client WHERE email LIKE '%@mail.ru%';

-- T2: Вставка новой записи с email @mail.ru
BEGIN;
INSERT INTO client (full_name, phone_number, email, driver_license) 
VALUES ('Фантомный Клиент', '+79169998877', 'phantom@mail.ru', 'PHANTOM123');
COMMIT;

-- T1: Повторный SELECT - все равно 4 (фантомное чтение предотвращено)
SELECT COUNT(*) FROM client WHERE email LIKE '%@mail.ru%';
COMMIT;

-- После COMMIT видим реальное количество клиентов - 5
SELECT COUNT(*) FROM client WHERE email LIKE '%@mail.ru%';


--- удаляем не нужного клиента  
SELECT * FROM client WHERE email = 'phantom@mail.ru';


--2.4.2
-- Первый запуск транзакций
-- T1: Чтение данных из таблицы клиентов
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT COUNT(*) FROM client;

-- T2: Чтение тех же данных и вставка нового клиента
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT COUNT(*) FROM client;
INSERT INTO client (full_name, phone_number, driver_license) 
VALUES ('Client A', '+79160000001', 'DL001');

-- T2: Успешное завершение
COMMIT; 

-- T1: Вставка клиента
INSERT INTO client (full_name, phone_number, driver_license) 
VALUES ('Client B', '+79160000002', 'DL002');

-- T1: Попытка завершить транзакцию 
COMMIT; -- не удалось сериализовать доступ из-за зависимостей чтения/записи между транзакциями

-- Второй запуск транзакций
-- T1: Чтение данных из таблицы клиентов
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT COUNT(*) FROM client;

-- T2: Чтение тех же данных и вставка нового клиента
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT COUNT(*) FROM client;
INSERT INTO client (full_name, phone_number, driver_license) 
VALUES ('Client A', '+79160000001', 'DL001');
COMMIT; -- повторяющееся значение ключа нарушает ограничение уникальности

-- T1: Вставка нового клиента 
INSERT INTO client (full_name, phone_number, driver_license) 
VALUES ('Client B', '+79160000002', 'DL002');

-- T1: Успешное завершение
COMMIT; 

--Удаляем ненужные данные о клиентах
DELETE FROM client 
WHERE full_name = 'Client B' 

DELETE FROM client 
WHERE full_name = 'Client A' 




--fn_proc.md
--1.3. Процедура для добавления нового клиента с картой лояльности
CREATE OR REPLACE PROCEDURE add_client_with_loyalty(
	new_full_name VARCHAR(100),
	new_phone_number VARCHAR(12),
	new_email VARCHAR(100),
	new_driver_license VARCHAR(20)
)
LANGUAGE plpgsql
AS $$
DECLARE
	new_client_id INT;
BEGIN
	-- вставка нового клиента
	INSERT INTO client (full_name, phone_number, email, driver_license)
	VALUES (new_full_name, new_phone_number, new_email, new_driver_license);

    -- id нового клиента
	SELECT id INTO new_client_id
	FROM client
	WHERE driver_license = new_driver_license;

    -- создание карты лояльности для клиента
	INSERT INTO loyalty_card (id_client, registration_date, points_balance)
	VALUES (new_client_id, CURRENT_DATE, 0);
END;
$$;

CALL add_client_with_loyalty('Петрова Мария Ивановна', '+79167654321', 'petrova@mail.ru', 'CD987654321');

SELECT c.id, c.full_name, c.phone_number, c.driver_license, lc.card_number, lc.points_balance
FROM client c
INNER JOIN loyalty_card lc ON c.id = lc.id_client;

--2.3. Функция для получения текущего баланса баллов лояльности клиента
CREATE OR REPLACE FUNCTION get_client_points(f_full_name VARCHAR(100), f_phone_number VARCHAR(12))
RETURNS INT
LANGUAGE plpgsql
AS $$
BEGIN
	RETURN (SELECT points_balance
			FROM loyalty_card 
			INNER JOIN client ON loyalty_card.id_client = client.id
			WHERE full_name = f_full_name AND phone_number = f_phone_number);
END;
$$;

SELECT get_client_points('Федорова Елена Александровна', '+79166789012') AS loyalty_points;

--2.6 Итоговая сумма заказа клиента с учетом скидки по баллам лояльности
CREATE OR REPLACE FUNCTION calculate_order_total_with_discount(f_order_id INT)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
	total_items INT;
	total_services INT;
	total_without_discount INT;
	client_points INT;
	f_discount_percent NUMERIC;
    final_total INT;	
BEGIN
    -- Сумма всех товаров в заказе
	SELECT COALESCE(SUM(total_price), 0) INTO total_items
	FROM client_order_items
	WHERE id_order = f_order_id; 

	-- Сумма всех услуг в заказе 
	SELECT COALESCE(SUM(total_price), 0) INTO total_services
	FROM client_order_services
	WHERE id_order = f_order_id; 

	-- Общая сумма без скидки
    total_without_discount := total_items + total_services;

	-- Баллы лояльности клиента 
    SELECT COALESCE(lc.points_balance, 0) INTO client_points
    FROM client_order co
    INNER JOIN loyalty_card lc ON co.id_client = lc.id_client
    WHERE co.id = f_order_id;

	-- Максимальная доступная скидка по баллам 
    SELECT COALESCE(MAX(discount_percent), 0) INTO f_discount_percent
    FROM loyalty_rules
    WHERE min_points <= client_points;

	-- Итоговая сумма со скидкой
    final_total := total_without_discount * (1 - f_discount_percent / 100);

	RETURN final_total;
END;
$$;

SELECT calculate_order_total_with_discount(1) AS final_amount;

-- Добавление данных (сначала выполнить 3.3, потом добавляем, потом опять 3.3)
-- Добавляем товары в выполненные заказы где total_amount = 0
INSERT INTO client_order_items (id_order, product_price_id, quantity, unit_price)
SELECT 
    co.id, 
    (SELECT id FROM product_prices ORDER BY RANDOM() LIMIT 1),
    FLOOR(RANDOM() * 5 + 1)::INTEGER,
    FLOOR(RANDOM() * 5000 + 500)::INTEGER
FROM client_order co
WHERE co.status = 'выполнен' 
AND co.total_amount = 0
AND NOT EXISTS (SELECT 1 FROM client_order_items WHERE id_order = co.id);

-- Добавляем услуги в выполненные заказы где total_amount = 0
INSERT INTO client_order_services (id_order, service_price_id, quantity, unit_price)
SELECT 
    co.id, 
    (SELECT id FROM service_prices ORDER BY RANDOM() LIMIT 1),
    1,
    FLOOR(RANDOM() * 10000 + 1000)::INTEGER
FROM client_order co
WHERE co.status = 'выполнен' 
AND co.total_amount = 0
AND NOT EXISTS (SELECT 1 FROM client_order_services WHERE id_order = co.id);

--3.3. Обновленные суммы в выполненных заказах, рассчитанные с учетом скидки по баллам лояльности клиентов.
DO $$
BEGIN
    UPDATE client_order 
    SET total_amount = calculate_order_total_with_discount(id)
    WHERE status = 'выполнен';
END $$;

--6.1. Процедура для добавления 100 баллов первым 3 клиентам с наибольшим количеством заказов
CREATE OR REPLACE PROCEDURE add_points_to_top_clients()
LANGUAGE plpgsql
AS $$
DECLARE
    client_id INTEGER;
    i INTEGER := 1;
BEGIN
    WHILE i <= 3 LOOP
        SELECT co.id_client INTO client_id
        FROM client_order co
        GROUP BY co.id_client
        ORDER BY COUNT(*) DESC
        LIMIT 1
        OFFSET i - 1;
        
        UPDATE loyalty_card 
        SET points_balance = points_balance + 100
        WHERE id_client = client_id;
        
        i := i + 1;
    END LOOP;
END;
$$;

CALL add_points_to_top_clients();

--7.2. Функция для расчета средней суммы заказа клиента с обработкой деления на ноль
CREATE OR REPLACE FUNCTION calculate_avg_order_amount(f_client_id INTEGER)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    f_total_orders INTEGER;
    f_total_amount INTEGER;
    f_avg_amount NUMERIC;
BEGIN
    SELECT COUNT(*), COALESCE(SUM(total_amount), 0)
    INTO f_total_orders, f_total_amount
    FROM client_order
    WHERE id_client = f_client_id;
    
    f_avg_amount := f_total_amount / f_total_orders;
    
    RETURN f_avg_amount;
    
EXCEPTION
    WHEN division_by_zero THEN
        RAISE NOTICE 'У клиента ID % нет заказов', f_client_id;
        RETURN 0;
	WHEN OTHERS THEN
		RAISE NOTICE 'Ошибка расчета';
	    RETURN -1;
END;
$$;

SELECT calculate_avg_order_amount(1); 
SELECT calculate_avg_order_amount(999); 

CREATE TABLE client_order_status_log (
    id SERIAL PRIMARY KEY, 
    order_id INTEGER NOT NULL, 
    status order_status NOT NULL,
    changes_date date DEFAULT CURRENT_DATE NOT NULL,
    FOREIGN KEY (order_id) REFERENCES client_order(id)
);
--1.2
CREATE OR REPLACE PROCEDURE create_car_service_order(
    p_client_id INTEGER,
    p_car_id INTEGER,
    p_location_id INTEGER,
    p_employee_id INTEGER,
    p_notes TEXT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Создаем новый заказ
    INSERT INTO client_order (id_client, id_car, id_location, employee_id, notes, status)
    VALUES (p_client_id, p_car_id, p_location_id, p_employee_id, p_notes, 'создан');
    
    -- Обновляем дату последнего визита в карте лояльности
    UPDATE loyalty_card 
    SET last_visit_date = CURRENT_DATE 
    WHERE id_client = p_client_id;
END;
$$;

SELECT 
    id AS order_id,
    id_client,
    created_date,
    status
FROM client_order 
WHERE id_client = 2 
ORDER BY id DESC 
LIMIT 2;

CALL create_car_service_order(2, 2, 1, 1, 'Диагностика ходовой');

SELECT 
    id AS order_id,
    id_client,
    created_date,
    status,
    notes
FROM client_order 
WHERE id_client = 2 
ORDER BY id DESC 
LIMIT 3;

SELECT 
    c.full_name,
    lc.last_visit_date,
    lc.points_balance
FROM loyalty_card lc
JOIN client c ON lc.id_client = c.id
WHERE lc.id_client = 2;

--2.2
CREATE OR REPLACE FUNCTION calculate_oil_change_cost_simple(
    p_car_model_id INTEGER,
    p_oil_quantity INTEGER
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    oil_price INTEGER;
    service_cost INTEGER;
    total_cost INTEGER;
BEGIN
    SELECT price INTO oil_price
    FROM product_prices pp
    JOIN nomenclature n ON pp.article = n.article
    WHERE n.name LIKE '%Моторное масло%'
    ORDER BY pp.effective_date DESC
    LIMIT 1;
    
    SELECT price INTO service_cost
    FROM service_prices
    WHERE service_name = 'Замена масла'
    ORDER BY effective_date DESC
    LIMIT 1;
    
    total_cost := (oil_price * p_oil_quantity) + service_cost;
    
    RETURN total_cost;
END;
$$;

SELECT 
    1 AS car_model_id,
    5 AS oil_quantity,
    (SELECT model_name FROM car_model WHERE id = 1) AS car_model,
    calculate_oil_change_cost_simple(1, 5) AS total_cost;




-- trigger_cron.md
-- 1.1. Обновление last_visit_date при создании нового заказа клиента.
CREATE OR REPLACE FUNCTION update_last_visit_date()
RETURNS TRIGGER AS $$
BEGIN
	UPDATE loyalty_card 
	SET last_visit_date = CURRENT_DATE
	WHERE id_client = NEW.id_client;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_last_visit_trigger
AFTER INSERT ON client_order
FOR EACH ROW
EXECUTE FUNCTION update_last_visit_date();

-- Создаем новый заказ для клиента с id=1
INSERT INTO client_order (
    id_client, 
    id_car, 
    id_location, 
    employee_id, 
    total_amount, 
    status, 
    created_date, 
    priority
) VALUES (
    1,  1,  1,  1,  500000, 'создан', CURRENT_TIMESTAMP, 'обычный' );
	
-- 1.4. Обновление остатков товаров на точке при доставке заказа от поставщика.
 CREATE OR REPLACE FUNCTION update_remains_on_supplier_delivery()
 RETURNS TRIGGER AS $$
 BEGIN 
 	IF OLD.status != 'доставлен' AND NEW.status = 'доставлен' THEN
		-- Обновление существующих товаров
		WITH existing_items_to_update AS (
            SELECT soi.article, soi.quantity
            FROM supplier_order_items soi
			WHERE soi.id_order = OLD.id
            AND EXISTS (
                SELECT 1 FROM remains_of_goods rg
                WHERE rg.location_id = OLD.id_location
                AND rg.article = soi.article
            )
        )

        UPDATE remains_of_goods rg
		SET quantity = rg.quantity + eitu.quantity
		FROM existing_items_to_update eitu
        WHERE rg.location_id = OLD.id_location
        AND rg.article = eitu.article;

		-- Добавление новых товаров
		WITH new_items_to_insert AS (
            SELECT soi.article, soi.quantity
            FROM supplier_order_items soi
            WHERE soi.id_order = OLD.id
            AND NOT EXISTS (
                SELECT 1 FROM remains_of_goods rg
                WHERE rg.location_id = OLD.id_location
                AND rg.article = soi.article
            )
        )

		INSERT INTO remains_of_goods (location_id, article, quantity)
        SELECT OLD.id_location, article, quantity
        FROM new_items_to_insert;
        
        -- Обновление даты доставки
        IF NEW.expected_delivery_date IS NULL THEN
            NEW.expected_delivery_date := CURRENT_DATE;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_remains_on_supplier_delivery_trigger
AFTER UPDATE ON order_to_supplier
FOR EACH ROW
EXECUTE FUNCTION update_remains_on_supplier_delivery();

-- Доставляем заказ
UPDATE order_to_supplier 
SET status = 'доставлен'
WHERE id = 2 AND status = 'отправлен';

-- 1.7. Начисление бонусных баллов после выполнения заказа.
CREATE OR REPLACE FUNCTION add_loyalty_points()
RETURNS TRIGGER AS $$
BEGIN 
	IF OLD.status != 'выполнен' AND NEW.status = 'выполнен' THEN
		UPDATE loyalty_card 
		SET points_balance = points_balance + (NEW.total_amount * 0.01)::integer
		WHERE id_client = NEW.id_client;
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER add_loyalty_points_trigger
AFTER UPDATE ON client_order
FOR EACH ROW
EXECUTE FUNCTION add_loyalty_points();

-- Выполняем заказ
UPDATE client_order 
SET 
    status = 'выполнен',
    completion_date = CURRENT_TIMESTAMP
WHERE id = 2
AND status = 'в работе';

-- 1.10. Проверка дублирования телефонов клиентов.
CREATE OR REPLACE FUNCTION prevent_duplicate_phone()
RETURNS TRIGGER AS $$
BEGIN
	IF EXISTS (
		SELECT 1 
		FROM client 
		WHERE phone_number = NEW.phone_number AND id != NEW.id
	) THEN 
		RAISE EXCEPTION 'Клиент с номером телефона % уже существует', NEW.phone_number;
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER prevent_duplicate_phone_trigger
BEFORE INSERT OR UPDATE ON client
FOR EACH ROW
EXECUTE FUNCTION prevent_duplicate_phone();

-- Пробуем вставить дубликат
INSERT INTO client (full_name, phone_number, email, driver_license) 
VALUES (
    'Пушкин Александр Сергеевич',
    (SELECT phone_number FROM client WHERE id = 1), 
    'duplicate@test.ru',
    '77XX000001'
);


--1.3
CREATE OR REPLACE FUNCTION log_email_change()
RETURNS TRIGGER AS $$
BEGIN
    RAISE NOTICE 'Клиент % изменил email с % на %', OLD.full_name, OLD.email, NEW.email;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER email_change_trigger
BEFORE UPDATE OF email ON client
FOR EACH ROW
WHEN (OLD.email IS DISTINCT FROM NEW.email)
EXECUTE FUNCTION log_email_change();

SELECT id, full_name, email FROM client WHERE id = 1;

UPDATE client SET email = 'test_new_email@mail.ru' WHERE id = 1;

SELECT id, full_name, email FROM client WHERE id = 1;

--1.6
CREATE OR REPLACE FUNCTION check_car_year()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.year > EXTRACT(YEAR FROM CURRENT_DATE) THEN
        RAISE EXCEPTION 'Год выпуска не может быть больше текущего!';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER before_insert_car_year
BEFORE INSERT OR UPDATE ON car
FOR EACH ROW
EXECUTE FUNCTION check_car_year();

INSERT INTO car (vin, year, license_plate, color, model_id) 
VALUES ('TESTVIN123456789', 2030, 'А999АА777', 'Черный', 1);

INSERT INTO car (vin, year, license_plate, color, model_id) 
VALUES ('TESTVIN123456789', 2024, 'А999АА777', 'Черный', 1);

--1.9
CREATE OR REPLACE FUNCTION set_completion_date()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'выполнен' AND OLD.status != 'выполнен' THEN
        NEW.completion_date := CURRENT_TIMESTAMP;
        RAISE NOTICE 'Заказ ID % выполнен. Дата выполнения: %', NEW.id, NEW.completion_date;
    
    ELSIF OLD.status = 'выполнен' AND NEW.status != 'выполнен' THEN
        NEW.completion_date := NULL;
        RAISE NOTICE 'Заказ ID % больше не выполнен. Дата выполнения сброшена.', NEW.id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS before_order_status_update ON client_order;
CREATE TRIGGER before_order_status_update
BEFORE UPDATE OF status ON client_order
FOR EACH ROW
EXECUTE FUNCTION set_completion_date();

SELECT id, status, completion_date FROM client_order WHERE id = 2;

UPDATE client_order SET status = 'выполнен' WHERE id = 2;

SELECT id, status, completion_date FROM client_order WHERE id = 2;

--1.12
CREATE OR REPLACE FUNCTION log_mass_delete()
RETURNS TRIGGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    RAISE NOTICE 'Операция: %, Таблица: %, Затронуто строк: %', 
        TG_OP, TG_TABLE_NAME, deleted_count;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS after_mass_delete_client_order ON client_order;
CREATE TRIGGER after_mass_delete_client_order
AFTER DELETE ON client_order
FOR EACH STATEMENT
EXECUTE FUNCTION log_mass_delete();

SELECT id, status, created_date FROM client_order co ;

DELETE FROM client_order 
WHERE status = '' 
AND created_date < '2024-01-01';

-- Аделины
CREATE OR REPLACE FUNCTION check_is_clients_car()
RETURNS TRIGGER AS $$
DECLARE 
    is_clients_car BOOLEAN;
BEGIN
    SELECT EXISTS(
        SELECT 1 FROM car_client 
        WHERE car_id = NEW.id_car AND client_id=NEW.id_client) 
    INTO is_clients_car;
    
    IF NOT is_clients_car THEN 
        RAISE EXCEPTION 'Автомобиль не привязан к данному клиенту';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;  

CREATE TRIGGER validate_client_order
BEFORE INSERT OR UPDATE ON client_order
FOR EACH ROW 
EXECUTE FUNCTION check_is_clients_car();

CREATE OR REPLACE FUNCTION create_loyalty_card()
RETURNS TRIGGER AS $$
DECLARE 
BEGIN
    INSERT INTO loyalty_card 
        (id_client)
    VALUES 
        (NEW.id);
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;  

CREATE TRIGGER create_client
AFTER INSERT OR UPDATE ON client
FOR EACH ROW 
EXECUTE FUNCTION create_loyalty_card();

CREATE OR REPLACE FUNCTION check_max_created_orders()
    RETURNS TRIGGER AS $$
DECLARE
    max_created_orders INTEGER := 10;
BEGIN
    IF (SELECT COUNT(*) FROM client_order WHERE status = 'создан') > max_created_orders THEN
        RAISE EXCEPTION 'Максимум % заказов со статусом "создан"', max_created_orders;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_max_created_orders
    AFTER INSERT OR UPDATE ON client_order
    FOR EACH STATEMENT 
EXECUTE FUNCTION check_max_created_orders();

CREATE OR REPLACE FUNCTION log_client_order_status()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO client_order_status_log (order_id, status)
        VALUES (NEW.id, NEW.status);
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER change_client_order_status
AFTER UPDATE ON client_order
FOR EACH ROW 
EXECUTE FUNCTION log_client_order_status();
-- 2.1
SELECT DISTINCT
    trigger_name,
    event_object_table as table_name
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;

-- 3.3. Ежедневная проверка истекших карт лояльности
SELECT cron.schedule(
	'daily_loyalty_check',
	'0 0 * * *'
	$$
	-- Если карта зарегистрирована больше 2 лет назад и нет посещений больше года - деактивируем
	UPDATE loyalty_card 
	SET points_balance = 0
	WHERE registration_date < CURRENT_DATE - INTERVAL '2 years'
	AND (last_visit_date IS NULL OR last_visit_date < CURRENT_DATE - INTERVAL '1 year');
	$$
);

