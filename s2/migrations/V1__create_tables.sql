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