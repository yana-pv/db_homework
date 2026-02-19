using Npgsql;
using Bogus;

namespace AutoserviceDataGenerator;

class Program
{
    static async Task Main(string[] args)
    {
        Console.WriteLine("Генератор данных для автосервиса");
        Console.WriteLine("==================================");

        string connectionString = "Host=localhost;Port=5438;Database=autoservice;Username=admin;Password=admin";

        await using var conn = new NpgsqlConnection(connectionString);
        await conn.OpenAsync();

        Console.WriteLine("Подключение к БД успешно!");

        // 1. Генерация клиентов (250,000)
        await GenerateClients(conn, 250000);

        // 2. Генерация автомобилей (250,000)
        await GenerateCars(conn, 250000);

        // 3. Генерация связей клиент-автомобиль (300,000)
        await GenerateCarClientRelations(conn, 300000);

        // 4. Генерация сотрудников (100,000)
        await GenerateEmployees(conn, 100000);

        // 5. Генерация заказов (500,000)
        await GenerateOrders(conn, 500000);

        Console.WriteLine("Генерация данных завершена!");
    }

    static async Task GenerateClients(NpgsqlConnection conn, int count)
    {
        Console.WriteLine($"Генерация {count} клиентов...");

        // Faker для русских данных
        var faker = new Faker("ru");

        var batchSize = 1000;
        var processed = 0;

        while (processed < count)
        {
            using var cmd = new NpgsqlCommand();
            cmd.Connection = conn;

            var values = new List<string>();
            var parameters = new List<NpgsqlParameter>();

            var batchCount = Math.Min(batchSize, count - processed);

            for (int i = 0; i < batchCount; i++)
            {
                var paramIdx = processed + i;

                // Генерация с разными распределениями
                string fullName = faker.Name.FullName();

                // Равномерное распределение телефонных номеров
                string phone = "+7" + faker.Random.Number(900, 999) + faker.Random.Number(1000000, 9999999);

                // Email - высокая кардинальность (уникальные)
                string email = faker.Internet.Email();

                // DriverLicense - 90% уникальные, 10% NULL (высокая селективность)
                string? driverLicense = null;
                if (faker.Random.Int(1, 100) > 10) // 90% не NULL
                {
                    driverLicense = faker.Random.AlphaNumeric(10).ToUpper();
                }

                values.Add($"(@fullName_{paramIdx}, @phone_{paramIdx}, @email_{paramIdx}, @dl_{paramIdx})");

                parameters.Add(new NpgsqlParameter($"@fullName_{paramIdx}", fullName));
                parameters.Add(new NpgsqlParameter($"@phone_{paramIdx}", phone));
                parameters.Add(new NpgsqlParameter($"@email_{paramIdx}", email));
                parameters.Add(new NpgsqlParameter($"@dl_{paramIdx}", driverLicense ?? (object)DBNull.Value));
            }

            cmd.CommandText = $@"
                INSERT INTO client (full_name, phone_number, email, driver_license) 
                VALUES {string.Join(", ", values)}";

            cmd.Parameters.AddRange(parameters.ToArray());

            await cmd.ExecuteNonQueryAsync();

            processed += batchCount;
            Console.WriteLine($"  Клиентов: {processed}/{count}");
        }

        Console.WriteLine($"✅ Клиенты готовы: {processed}");
    }

    static async Task GenerateCars(NpgsqlConnection conn, int count)
    {
        Console.WriteLine($"Генерация {count} автомобилей...");

        // Получаем существующие model_id
        var modelIds = await GetIds(conn, "car_model");

        var faker = new Faker("ru");
        var batchSize = 1000;
        var processed = 0;

        while (processed < count)
        {
            using var cmd = new NpgsqlCommand();
            cmd.Connection = conn;

            var values = new List<string>();
            var parameters = new List<NpgsqlParameter>();

            var batchCount = Math.Min(batchSize, count - processed);

            for (int i = 0; i < batchCount; i++)
            {
                var paramIdx = processed + i;

                // VIN - высокая кардинальность
                string vin = faker.Vehicle.Vin();

                // Год - равномерное распределение
                int year = faker.Random.Int(2000, 2024);

                // Номерной знак - 80% есть, 20% NULL
                string? plate = null;
                if (faker.Random.Int(1, 100) <= 80)
                {
                    plate = faker.Random.AlphaNumeric(6).ToUpper();
                }

                // Цвет - неравномерное распределение
                string[] colors = { "черный", "белый", "серебристый", "синий", "красный", "серый", "зеленый" };
                float[] colorProbs = { 0.30f, 0.25f, 0.15f, 0.10f, 0.08f, 0.07f, 0.05f }; // черных 30%
                string color = faker.Random.WeightedRandom(colors, colorProbs);

                // Модель - неравномерное распределение (Zipf-подобное)
                float[] modelProbs = Enumerable.Range(1, modelIds.Count)
                    .Select(x => (float)(1.0 / x))
                    .ToArray();
                int modelId = faker.Random.WeightedRandom(modelIds.ToArray(), modelProbs);

                values.Add($"(@vin_{paramIdx}, @year_{paramIdx}, @plate_{paramIdx}, @color_{paramIdx}, @modelId_{paramIdx})");

                parameters.Add(new NpgsqlParameter($"@vin_{paramIdx}", vin));
                parameters.Add(new NpgsqlParameter($"@year_{paramIdx}", year));
                parameters.Add(new NpgsqlParameter($"@plate_{paramIdx}", plate ?? (object)DBNull.Value));
                parameters.Add(new NpgsqlParameter($"@color_{paramIdx}", color));
                parameters.Add(new NpgsqlParameter($"@modelId_{paramIdx}", modelId));
            }

            cmd.CommandText = $@"
                INSERT INTO car (vin, year, license_plate, color, model_id) 
                VALUES {string.Join(", ", values)}";

            cmd.Parameters.AddRange(parameters.ToArray());

            await cmd.ExecuteNonQueryAsync();

            processed += batchCount;
            Console.WriteLine($"  Автомобилей: {processed}/{count}");
        }

        Console.WriteLine($"✅ Автомобили готовы: {processed}");
    }

    static async Task GenerateCarClientRelations(NpgsqlConnection conn, int count)
    {
        Console.WriteLine($"Генерация {count} связей клиент-автомобиль...");

        var carIds = await GetIds(conn, "car");
        var clientIds = await GetIds(conn, "client");

        var faker = new Faker();
        var batchSize = 1000;
        var processed = 0;

        var usedPairs = new HashSet<(int, int)>();

        while (processed < count)
        {
            using var cmd = new NpgsqlCommand();
            cmd.Connection = conn;

            var values = new List<string>();
            var parameters = new List<NpgsqlParameter>();

            var batchCount = Math.Min(batchSize, count - processed);
            var batchPairs = new List<(int carId, int clientId)>();

            for (int i = 0; i < batchCount; i++)
            {
                int carId, clientId;
                do
                {
                    // Перекос: 70% связей с 30% клиентов
                    if (faker.Random.Int(1, 100) <= 70)
                    {
                        // Активные клиенты (первые 30%)
                        clientId = faker.Random.Int(1, (int)(clientIds.Count * 0.3));
                    }
                    else
                    {
                        clientId = faker.Random.Int((int)(clientIds.Count * 0.3) + 1, clientIds.Count);
                    }

                    carId = faker.Random.Int(1, carIds.Count);
                }
                while (usedPairs.Contains((carId, clientId)));

                batchPairs.Add((carId, clientId));
                usedPairs.Add((carId, clientId));

                var paramIdx = processed + i;
                values.Add($"(@car_{paramIdx}, @client_{paramIdx})");
                parameters.Add(new NpgsqlParameter($"@car_{paramIdx}", carId));
                parameters.Add(new NpgsqlParameter($"@client_{paramIdx}", clientId));
            }

            cmd.CommandText = $@"
                INSERT INTO car_client (car_id, client_id) 
                VALUES {string.Join(", ", values)}";

            cmd.Parameters.AddRange(parameters.ToArray());

            try
            {
                await cmd.ExecuteNonQueryAsync();
            }
            catch (PostgresException ex) when (ex.SqlState == "23505") // unique violation
            {
                // Пропускаем дубликаты
            }

            processed += batchCount;
            Console.WriteLine($"  Связей: {processed}/{count}");
        }

        Console.WriteLine($"✅ Связи готовы: {processed}");
    }

    static async Task GenerateEmployees(NpgsqlConnection conn, int count)
    {
        Console.WriteLine($"Генерация {count} сотрудников...");

        var locationIds = await GetIds(conn, "location");
        var faker = new Faker("ru");

        var batchSize = 1000;
        var processed = 0;

        string[] positions = {
        "механик", "старший механик", "диагност", "электрик",
        "менеджер", "администратор", "мастер-приемщик", "директор"
    };
        float[] positionProbs = { 0.35f, 0.15f, 0.10f, 0.10f, 0.10f, 0.08f, 0.07f, 0.05f };

        string[] statuses = { "работает", "отпуск", "уволен" };
        float[] statusProbs = { 0.80f, 0.15f, 0.05f };

        while (processed < count)
        {
            using var cmd = new NpgsqlCommand();
            cmd.Connection = conn;

            var values = new List<string>();
            var parameters = new List<NpgsqlParameter>();

            var batchCount = Math.Min(batchSize, count - processed);

            for (int i = 0; i < batchCount; i++)
            {
                var paramIdx = processed + i;

                string position = faker.Random.WeightedRandom(positions, positionProbs);

                float[] locationProbs = Enumerable.Range(1, locationIds.Count)
                    .Select(x => (float)(1.0 / x))
                    .ToArray();
                int locationId = faker.Random.WeightedRandom(locationIds.ToArray(), locationProbs);

                string status = faker.Random.WeightedRandom(statuses, statusProbs);
                string fullName = faker.Name.FullName();
                string phone = "+7" + faker.Random.Number(900, 999) + faker.Random.Number(1000000, 9999999);
                DateTime hireDate = faker.Date.Past(5, DateTime.Now.AddYears(-1));

                values.Add($"(@pos_{paramIdx}, @loc_{paramIdx}, @status_{paramIdx}, @name_{paramIdx}, @phone_{paramIdx}, @hire_{paramIdx})");

                parameters.Add(new NpgsqlParameter($"@pos_{paramIdx}", position));
                parameters.Add(new NpgsqlParameter($"@loc_{paramIdx}", locationId));

                parameters.Add(new NpgsqlParameter($"@status_{paramIdx}", NpgsqlTypes.NpgsqlDbType.Unknown) { Value = status });

                parameters.Add(new NpgsqlParameter($"@name_{paramIdx}", fullName));
                parameters.Add(new NpgsqlParameter($"@phone_{paramIdx}", phone));
                parameters.Add(new NpgsqlParameter($"@hire_{paramIdx}", hireDate));
            }

            cmd.CommandText = $@"
            INSERT INTO employee (position, location_id, status, full_name, phone_number, hire_date) 
            VALUES {string.Join(", ", values)}";

            cmd.Parameters.AddRange(parameters.ToArray());

            await cmd.ExecuteNonQueryAsync();

            processed += batchCount;
            Console.WriteLine($"  Сотрудников: {processed}/{count}");
        }

        Console.WriteLine($"✅ Сотрудники готовы: {processed}");
    }

    static async Task GenerateOrders(NpgsqlConnection conn, int count)
    {
        Console.WriteLine($"Генерация {count} заказов...");

        var clientIds = await GetIds(conn, "client");
        var carIds = await GetIds(conn, "car");
        var locationIds = await GetIds(conn, "location");
        var employeeIds = await GetIds(conn, "employee");
        var productPriceIds = await GetProductPriceIds(conn);
        var servicePriceIds = await GetServicePriceIds(conn);

        var faker = new Faker("ru");
        var batchSize = 500; // Меньше из-за связанных записей
        var processed = 0;

        string[] statuses = { "создан", "в работе", "выполнен", "отменен" };
        float[] statusProbs = { 0.10f, 0.30f, 0.50f, 0.10f };

        string[] priorities = { "низкий", "обычный", "высокий", "срочный" };
        float[] priorityProbs = { 0.15f, 0.60f, 0.20f, 0.05f };

        while (processed < count)
        {
            using var cmd = new NpgsqlCommand();
            cmd.Connection = conn;

            var values = new List<string>();
            var parameters = new List<NpgsqlParameter>();

            var batchCount = Math.Min(batchSize, count - processed);
            var orderIds = new List<int>();

            // Вставляем заказы
            for (int i = 0; i < batchCount; i++)
            {
                var paramIdx = processed + i;

                // Перекос: 70% заказов от 30% клиентов
                int clientId;
                if (faker.Random.Int(1, 100) <= 70)
                {
                    // Активные клиенты (первые 30%)
                    clientId = faker.Random.Int(1, (int)(clientIds.Count * 0.3));
                }
                else
                {
                    clientId = faker.Random.Int((int)(clientIds.Count * 0.3) + 1, clientIds.Count);
                }

                int carId = faker.Random.Int(1, carIds.Count);
                int locationId = faker.Random.Int(1, locationIds.Count);
                int employeeId = faker.Random.Int(1, employeeIds.Count);

                DateTime createdDate = faker.Date.Past(1);
                DateTime? completionDate = null;
                string status = faker.Random.WeightedRandom(statuses, statusProbs);

                if (status == "выполнен")
                {
                    completionDate = createdDate.AddHours(faker.Random.Int(1, 48));
                }

                string notes = faker.Random.Int(1, 100) <= 30 ? faker.Lorem.Sentence() : null; // 30% с заметками

                string priority = faker.Random.WeightedRandom(priorities, priorityProbs);

                values.Add($"(@client_{paramIdx}, @car_{paramIdx}, @loc_{paramIdx}, @emp_{paramIdx}, @created_{paramIdx}, @completion_{paramIdx}, @status_{paramIdx}, @notes_{paramIdx}, @priority_{paramIdx})");

                parameters.Add(new NpgsqlParameter($"@client_{paramIdx}", clientId));
                parameters.Add(new NpgsqlParameter($"@car_{paramIdx}", carId));
                parameters.Add(new NpgsqlParameter($"@loc_{paramIdx}", locationId));
                parameters.Add(new NpgsqlParameter($"@emp_{paramIdx}", employeeId));
                parameters.Add(new NpgsqlParameter($"@created_{paramIdx}", createdDate));
                parameters.Add(new NpgsqlParameter($"@completion_{paramIdx}", completionDate ?? (object)DBNull.Value));
                parameters.Add(new NpgsqlParameter($"@status_{paramIdx}", NpgsqlTypes.NpgsqlDbType.Unknown) { Value = status });
                parameters.Add(new NpgsqlParameter($"@priority_{paramIdx}", NpgsqlTypes.NpgsqlDbType.Unknown) { Value = priority });
                parameters.Add(new NpgsqlParameter($"@notes_{paramIdx}", notes ?? (object)DBNull.Value));
            }

            cmd.CommandText = $@"
                INSERT INTO client_order 
                (id_client, id_car, id_location, employee_id, created_date, completion_date, status, notes, priority) 
                VALUES {string.Join(", ", values)}
                RETURNING id";

            cmd.Parameters.AddRange(parameters.ToArray());

            using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                orderIds.Add(reader.GetInt32(0));
            }

            await reader.CloseAsync();

            // Добавляем элементы заказа и услуги
            foreach (var orderId in orderIds)
            {
                // 1-5 товаров в заказе
                int itemsCount = faker.Random.Int(1, 5);
                for (int j = 0; j < itemsCount; j++)
                {
                    var priceId = faker.PickRandom(productPriceIds);
                    int quantity = faker.Random.Int(1, 3);
                    int unitPrice = faker.Random.Int(500, 5000) * 100; // в копейках

                    using var itemCmd = new NpgsqlCommand();
                    itemCmd.Connection = conn;
                    itemCmd.CommandText = @"
                        INSERT INTO client_order_items (id_order, product_price_id, quantity, unit_price)
                        VALUES (@orderId, @priceId, @quantity, @unitPrice)";

                    itemCmd.Parameters.AddWithValue("@orderId", orderId);
                    itemCmd.Parameters.AddWithValue("@priceId", priceId);
                    itemCmd.Parameters.AddWithValue("@quantity", quantity);
                    itemCmd.Parameters.AddWithValue("@unitPrice", unitPrice);

                    await itemCmd.ExecuteNonQueryAsync();
                }

                // 0-3 услуги в заказе
                int servicesCount = faker.Random.Int(0, 3);
                for (int j = 0; j < servicesCount; j++)
                {
                    var priceId = faker.PickRandom(servicePriceIds);
                    int unitPrice = faker.Random.Int(1000, 10000) * 100; // в копейках

                    using var serviceCmd = new NpgsqlCommand();
                    serviceCmd.Connection = conn;
                    serviceCmd.CommandText = @"
                        INSERT INTO client_order_services (id_order, service_price_id, unit_price)
                        VALUES (@orderId, @priceId, @unitPrice)";

                    serviceCmd.Parameters.AddWithValue("@orderId", orderId);
                    serviceCmd.Parameters.AddWithValue("@priceId", priceId);
                    serviceCmd.Parameters.AddWithValue("@unitPrice", unitPrice);

                    await serviceCmd.ExecuteNonQueryAsync();
                }

                // Обновляем общую сумму заказа
                using var updateCmd = new NpgsqlCommand();
                updateCmd.Connection = conn;
                updateCmd.CommandText = @"
                    UPDATE client_order 
                    SET total_amount = (
                        SELECT COALESCE(SUM(total_price), 0) FROM client_order_items WHERE id_order = @orderId
                    ) + (
                        SELECT COALESCE(SUM(total_price), 0) FROM client_order_services WHERE id_order = @orderId
                    )
                    WHERE id = @orderId";

                updateCmd.Parameters.AddWithValue("@orderId", orderId);
                await updateCmd.ExecuteNonQueryAsync();
            }

            processed += batchCount;
            Console.WriteLine($"  Заказов: {processed}/{count}");
        }

        Console.WriteLine($"✅ Заказы готовы: {processed}");
    }

    // Вспомогательные методы
    static async Task<List<int>> GetIds(NpgsqlConnection conn, string tableName)
    {
        var ids = new List<int>();
        using var cmd = new NpgsqlCommand($"SELECT id FROM {tableName} ORDER BY id", conn);
        using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            ids.Add(reader.GetInt32(0));
        }
        return ids;
    }

    static async Task<List<int>> GetProductPriceIds(NpgsqlConnection conn)
    {
        var ids = new List<int>();
        using var cmd = new NpgsqlCommand("SELECT id FROM product_prices", conn);
        using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            ids.Add(reader.GetInt32(0));
        }
        return ids;
    }

    static async Task<List<int>> GetServicePriceIds(NpgsqlConnection conn)
    {
        var ids = new List<int>();
        using var cmd = new NpgsqlCommand("SELECT id FROM service_prices", conn);
        using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            ids.Add(reader.GetInt32(0));
        }
        return ids;
    }
}