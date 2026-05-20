using Npgsql;

namespace TaskQueueSystem;

public class Monitor
{
    private readonly DatabaseConfig _dbConfig;
    private readonly List<(DateTime Time, int Lag, int Waiting, int Throughput)> _metrics = new();
    private long _lastCompleted = 0;
    private DateTime _lastMetricTime = DateTime.Now;

    public Monitor(DatabaseConfig dbConfig)
    {
        _dbConfig = dbConfig;
    }

    public async Task StartMonitoringAsync(CancellationToken cancellationToken = default)
    {
        Console.WriteLine("\n[Monitor] Запущен мониторинг. Отчёт каждые 5 секунд.\n");

        while (!cancellationToken.IsCancellationRequested)
        {
            await Task.Delay(5000, cancellationToken);

            await using var connection = new NpgsqlConnection(_dbConfig.GetConnectionString());
            await connection.OpenAsync(cancellationToken);

            // 1. Лаг очереди (разница между now() и created_at самой старой задачи)
            const string lagSql = @"
                SELECT 
                    COALESCE(EXTRACT(EPOCH FROM (NOW() - MIN(created_at)))::INT, 0) AS lag_seconds,
                    COUNT(*) AS waiting_count,
                    COUNT(*) FILTER (WHERE priority = 100) AS critical_waiting,
                    COUNT(*) FILTER (WHERE priority = 0) AS regular_waiting
                FROM tasks
                WHERE status = 'Ready' AND scheduled_at <= NOW()";

            await using var lagCmd = new NpgsqlCommand(lagSql, connection);
            await using var lagReader = await lagCmd.ExecuteReaderAsync(cancellationToken);

            int lagSeconds = 0;
            long waitingCount = 0;
            long criticalWaiting = 0;
            long regularWaiting = 0;

            if (await lagReader.ReadAsync(cancellationToken))
            {
                lagSeconds = lagReader.GetInt32(0);
                waitingCount = lagReader.GetInt64(1);
                criticalWaiting = lagReader.GetInt64(2);
                regularWaiting = lagReader.GetInt64(3);
            }
            await lagReader.CloseAsync();

            // 2. Общая статистика
            const string statsSql = @"
                SELECT 
                    COUNT(*) FILTER (WHERE status = 'Completed') AS completed_total,
                    COUNT(*) FILTER (WHERE status = 'Completed' AND priority = 100) AS critical_completed,
                    COUNT(*) FILTER (WHERE status = 'Completed' AND priority = 0) AS regular_completed,
                    COUNT(*) FILTER (WHERE status = 'Failed') AS failed_total,
                    COUNT(*) AS total_tasks
                FROM tasks";

            await using var statsCmd = new NpgsqlCommand(statsSql, connection);
            await using var statsReader = await statsCmd.ExecuteReaderAsync(cancellationToken);

            long completedTotal = 0;
            long criticalCompleted = 0;
            long regularCompleted = 0;
            long failedTotal = 0;
            long totalTasks = 0;

            if (await statsReader.ReadAsync(cancellationToken))
            {
                completedTotal = statsReader.GetInt64(0);
                criticalCompleted = statsReader.GetInt64(1);
                regularCompleted = statsReader.GetInt64(2);
                failedTotal = statsReader.GetInt64(3);
                totalTasks = statsReader.GetInt64(4);
            }
            await statsReader.CloseAsync();

            // 3. Пропускная способность (задач в секунду)
            var now = DateTime.Now;
            var elapsed = (now - _lastMetricTime).TotalSeconds;
            var throughput = (completedTotal - _lastCompleted) / elapsed;

            _metrics.Add((now, lagSeconds, (int)waitingCount, (int)throughput));
            _lastCompleted = completedTotal;
            _lastMetricTime = now;

            // Вывод отчёта
            Console.WriteLine($"\n{new string('=', 100)}");
            Console.WriteLine($"[{now:HH:mm:ss}] 📊 МОНИТОРИНГ ОЧЕРЕДИ");
            Console.WriteLine($"  ⏰ ЛАГ ОЧЕРЕДИ: {lagSeconds} сек (самая старая задача ждёт {lagSeconds} сек)");
            Console.WriteLine($"  📋 В ОЧЕРЕДИ: {waitingCount} задач (крит: {criticalWaiting}, обыч: {regularWaiting})");
            Console.WriteLine($"  ✅ ОБРАБОТАНО: {completedTotal} (крит: {criticalCompleted}, обыч: {regularCompleted})");
            Console.WriteLine($"  ❌ ОШИБОК: {failedTotal}");
            Console.WriteLine($"  ⚡ ПРОПУСКНАЯ СПОСОБНОСТЬ: {throughput:F1} задач/сек (суммарно оба воркера)");
            Console.WriteLine($"  📈 ВСЕГО СОЗДАНО: {totalTasks}");
            Console.WriteLine($"{new string('=', 100)}");

            // Предупреждение
            if (lagSeconds > 30)
            {
                Console.WriteLine($"  ⚠️  ВНИМАНИЕ! Очередь растёт! Лаг {lagSeconds} секунд. Увеличьте число воркеров.");
            }
        }
    }

    public void PrintFinalReport()
    {
        Console.WriteLine($"\n{new string('=', 100)}");
        Console.WriteLine("📊 ФИНАЛЬНЫЙ АНАЛИТИЧЕСКИЙ ОТЧЁТ");
        Console.WriteLine($"{new string('=', 100)}");

        Console.WriteLine("\n1. ДИНАМИКА ЛАГА ОЧЕРЕДИ:");
        Console.WriteLine("   Время → Лаг (сек) → Задач в очереди → Пропускная способность");
        foreach (var m in _metrics)
        {
            Console.WriteLine($"   {m.Time:HH:mm:ss} → {m.Lag} сек → {m.Waiting} задач → {m.Throughput} задач/сек");
        }

        if (_metrics.Count > 1)
        {
            var maxLag = _metrics.Max(m => m.Lag);
            var avgThroughput = _metrics.Average(m => m.Throughput);
            Console.WriteLine($"\n   📈 Максимальный лаг: {maxLag} секунд");
            Console.WriteLine($"   📈 Средняя пропускная способность: {avgThroughput:F1} задач/сек");
        }
    }
}
