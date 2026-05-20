using Npgsql;

namespace TaskQueueSystem;

class Program
{
    static async Task Main(string[] args)
    {
        Console.WriteLine("╔════════════════════════════════════════════════════════════════╗");
        Console.WriteLine("║     СИСТЕМА ОЧЕРЕДИ ЗАДАЧ НА POSTGRESQL - АНАЛИЗ ПРОИЗВОДИТЕЛЬНОСТИ    ║");
        Console.WriteLine("╚════════════════════════════════════════════════════════════════╝\n");

        var dbConfig = new DatabaseConfig
        {
            Host = "localhost",
            Port = 5438,
            Username = "admin",
            Password = "admin", // ⚠️ ИЗМЕНИТЕ НА ВАШ ПАРОЛЬ
            Database = "autoservice"
        };

        // Инициализация БД
        if (!await InitializeDatabaseAsync(dbConfig))
        {
            Console.WriteLine("❌ Не удалось подключиться к PostgreSQL. Проверьте:");
            Console.WriteLine("   1. Запущен ли PostgreSQL");
            Console.WriteLine("   2. Правильный ли пароль в DatabaseConfig");
            Console.WriteLine("   3. Существует ли БД 'task_queue'");
            Console.WriteLine("\nДля создания БД выполните: psql -U postgres -c \"CREATE DATABASE task_queue;\"");
            return;
        }

        Console.WriteLine("\nНастройка теста:");
        Console.WriteLine("  • Продьюсер: 100 задач/сек (80% обычных, 20% критических)");
        Console.WriteLine("  • Воркеры: 2 конкурентных обработчика");
        Console.WriteLine("  • Критические задачи обрабатываются в 4 раза быстрее (50ms vs 200ms)");
        Console.WriteLine("  • Тест длится: 2 минуты\n");

        using var cts = new CancellationTokenSource();

        // Автоматическая остановка через 2 минуты
        cts.CancelAfter(TimeSpan.FromMinutes(2));

        Console.CancelKeyPress += (sender, e) =>
        {
            Console.WriteLine("\n\n⚠️ Получен сигнал остановки...");
            e.Cancel = true;
            cts.Cancel();
        };

        var producer = new Producer(dbConfig);
        var worker1 = new Worker(1, dbConfig);
        var worker2 = new Worker(2, dbConfig);
        var monitor = new Monitor(dbConfig);

        Console.WriteLine("=== СИСТЕМА ЗАПУЩЕНА ===");
        Console.WriteLine("Легенда:");
        Console.WriteLine("  '.' - обычная задача добавлена");
        Console.WriteLine("  '!' - критическая задача добавлена");
        Console.WriteLine("  ✓[0] - обычная задача обработана успешно");
        Console.WriteLine("  ✓[100] - критическая задача обработана успешно");
        Console.WriteLine("  ✗[0]/✗[100] - ошибка обработки (будет retry через 5 минут)");
        Console.WriteLine("\nНажмите Ctrl+C для досрочной остановки\n");

        var producerTask = Task.Run(() => producer.StartProducingAsync(100, cts.Token));
        var workerTask1 = Task.Run(() => worker1.StartWorkingAsync(cts.Token));
        var workerTask2 = Task.Run(() => worker2.StartWorkingAsync(cts.Token));
        var monitorTask = Task.Run(() => monitor.StartMonitoringAsync(cts.Token));

        try
        {
            await Task.WhenAll(producerTask, workerTask1, workerTask2, monitorTask);
        }
        catch (OperationCanceledException)
        {
            Console.WriteLine("\n\n⏰ Тест завершён (2 минуты)");
        }

        // Финальный анализ
        await ShowPriorityAnalysis(dbConfig);
        monitor.PrintFinalReport();
        await ShowTableBloatAnalysis(dbConfig);

        Console.WriteLine("\nНажмите Enter для выхода...");
        Console.ReadLine();
    }

    static async Task<bool> InitializeDatabaseAsync(DatabaseConfig dbConfig)
    {
        try
        {
            await using var connection = new NpgsqlConnection(dbConfig.GetConnectionString());
            await connection.OpenAsync();

            const string createTable = @"
                DROP TABLE IF EXISTS tasks CASCADE;
                CREATE TABLE tasks (
                    id BIGSERIAL PRIMARY KEY,
                    task_type VARCHAR(50),
                    payload JSONB,
                    priority INT DEFAULT 0,
                    status VARCHAR(20) DEFAULT 'Ready',
                    attempts INT DEFAULT 0,
                    max_attempts INT DEFAULT 3,
                    created_at TIMESTAMP DEFAULT NOW(),
                    updated_at TIMESTAMP DEFAULT NOW(),
                    scheduled_at TIMESTAMP DEFAULT NOW(),
                    processing_started_at TIMESTAMP,
                    processing_completed_at TIMESTAMP,
                    error_message TEXT
                );
                
                CREATE INDEX idx_tasks_status_priority ON tasks(status, priority DESC, scheduled_at);
                CREATE INDEX idx_tasks_priority ON tasks(priority) WHERE status = 'Ready';
                CREATE INDEX idx_tasks_created ON tasks(created_at);";

            await using var cmd = new NpgsqlCommand(createTable, connection);
            await cmd.ExecuteNonQueryAsync();

            Console.WriteLine("✅ База данных инициализирована");
            return true;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"❌ Ошибка: {ex.Message}");
            return false;
        }
    }

    static async Task ShowPriorityAnalysis(DatabaseConfig dbConfig)
    {
        await using var connection = new NpgsqlConnection(dbConfig.GetConnectionString());
        await connection.OpenAsync();

        const string sql = @"
            SELECT 
                priority,
                COUNT(*) as total,
                AVG(EXTRACT(EPOCH FROM (processing_started_at - created_at))) as avg_wait_seconds,
                AVG(EXTRACT(EPOCH FROM (processing_completed_at - processing_started_at))) as avg_process_seconds,
                MIN(created_at) as first_created,
                MAX(processing_completed_at) as last_completed
            FROM tasks
            WHERE status = 'Completed'
            GROUP BY priority
            ORDER BY priority DESC";

        await using var cmd = new NpgsqlCommand(sql, connection);
        await using var reader = await cmd.ExecuteReaderAsync();

        Console.WriteLine($"\n{new string('=', 100)}");
        Console.WriteLine("🎯 АНАЛИЗ ПРИОРИТЕТНОСТИ ЗАДАЧ");
        Console.WriteLine($"{new string('=', 100)}");
        Console.WriteLine($"{"Приоритет",-10} {"Выполнено",-10} {"Ср. ожидание",-15} {"Ср. обработка",-15} ");
        Console.WriteLine(new string('-', 60));

        while (await reader.ReadAsync())
        {
            var priority = reader.GetInt32(0);
            var total = reader.GetInt64(1);
            var avgWait = reader.GetDouble(2);
            var avgProcess = reader.GetDouble(3);

            Console.WriteLine($"{priority,-10} {total,-10} {avgWait:F3} сек       {avgProcess:F3} сек");
        }

        Console.WriteLine("\n📌 ВЫВОД: Критические задачи (priority=100) обрабатываются БЫСТРЕЕ и имеют МЕНЬШЕЕ время ожидания,");
        Console.WriteLine("   даже если они были созданы позже обычных задач.");
    }

    static async Task ShowTableBloatAnalysis(DatabaseConfig dbConfig)
    {
        await using var connection = new NpgsqlConnection(dbConfig.GetConnectionString());
        await connection.OpenAsync();

        // Размер таблицы
        const string sizeSql = @"
            SELECT 
                pg_size_pretty(pg_total_relation_size('tasks')) as total_size,
                pg_size_pretty(pg_relation_size('tasks')) as table_size,
                pg_size_pretty(pg_indexes_size('tasks')) as indexes_size,
                (SELECT COUNT(*) FROM tasks WHERE status = 'Ready') as pending,
                (SELECT COUNT(*) FROM tasks WHERE status = 'Running') as running,
                (SELECT COUNT(*) FROM tasks WHERE status = 'Completed') as completed,
                (SELECT COUNT(*) FROM tasks WHERE status = 'Failed') as failed";

        await using var cmd = new NpgsqlCommand(sizeSql, connection);
        await using var reader = await cmd.ExecuteReaderAsync();

        Console.WriteLine($"\n{new string('=', 100)}");
        Console.WriteLine("📦 АНАЛИЗ РАЗМЕРА ТАБЛИЦЫ И РАЗДУВАНИЯ (BLOAT)");
        Console.WriteLine($"{new string('=', 100)}");

        if (await reader.ReadAsync())
        {
            Console.WriteLine($"  • Общий размер таблицы: {reader.GetString(0)}");
            Console.WriteLine($"  • Размер данных: {reader.GetString(1)}");
            Console.WriteLine($"  • Размер индексов: {reader.GetString(2)}");
            Console.WriteLine($"\n  • Задач в статусе Ready: {reader.GetInt64(3)}");
            Console.WriteLine($"  • Задач в статусе Running: {reader.GetInt64(4)}");
            Console.WriteLine($"  • Задач в статусе Completed: {reader.GetInt64(5)}");
            Console.WriteLine($"  • Задач в статусе Failed: {reader.GetInt64(6)}");
        }

        // Статистика по VACUUM
        const string vacuumSql = @"
            SELECT 
                n_dead_tup as dead_tuples,
                n_live_tup as live_tuples,
                last_vacuum,
                last_autovacuum,
                last_analyze
            FROM pg_stat_all_tables 
            WHERE relname = 'tasks'";

        await using var vacuumCmd = new NpgsqlCommand(vacuumSql, connection);
        await using var vacuumReader = await vacuumCmd.ExecuteReaderAsync();

        if (await vacuumReader.ReadAsync())
        {
            var deadTuples = vacuumReader.GetInt64(0);
            var liveTuples = vacuumReader.GetInt64(1);
            var deadRatio = deadTuples > 0 ? (double)deadTuples / (deadTuples + liveTuples) * 100 : 0;

            Console.WriteLine($"\n  • Мёртвых строк (dead tuples): {deadTuples}");
            Console.WriteLine($"  • Живых строк (live tuples): {liveTuples}");
            Console.WriteLine($"  • Процент раздувания: {deadRatio:F1}%");

            if (deadRatio > 10)
            {
                Console.WriteLine($"  ⚠️  Рекомендуется выполнить: VACUUM FULL tasks;");
            }
        }
    }
}