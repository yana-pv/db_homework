using Npgsql;
using NpgsqlTypes;
using System.Text.Json;
using System.Diagnostics;

namespace TaskQueueSystem;

public class Producer
{
    private readonly DatabaseConfig _dbConfig;
    private readonly Random _random = new();
    private readonly Stopwatch _stopwatch = new();
    private int _totalProduced = 0;
    private int _criticalCount = 0;
    private int _regularCount = 0;

    public Producer(DatabaseConfig dbConfig)
    {
        _dbConfig = dbConfig;
    }

    public async Task StartProducingAsync(int targetRate = 100, CancellationToken cancellationToken = default)
    {
        Console.WriteLine($"[Producer] Запуск. Целевая скорость: {targetRate} задач/сек");
        Console.WriteLine($"[Producer] Распределение: 80% обычных (priority=0), 20% критических (priority=100)");

        _stopwatch.Start();

        while (!cancellationToken.IsCancellationRequested)
        {
            var expectedTotal = targetRate * _stopwatch.Elapsed.TotalSeconds;
            if (_totalProduced < expectedTotal)
            {
                await InsertTaskAsync(cancellationToken);
                _totalProduced++;

                if (_totalProduced % 50 == 0)
                {
                    var actualRate = _totalProduced / _stopwatch.Elapsed.TotalSeconds;
                    Console.WriteLine($"\n[Producer] Произведено: {_totalProduced} (Крит: {_criticalCount}, Обыч: {_regularCount}) | Скорость: {actualRate:F1} задач/сек");
                }
            }
            else
            {
                await Task.Delay(1, cancellationToken);
            }
        }
    }

    private async Task InsertTaskAsync(CancellationToken cancellationToken)
    {
        await using var connection = new NpgsqlConnection(_dbConfig.GetConnectionString());
        await connection.OpenAsync(cancellationToken);

        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);

        try
        {
            // 80% обычных, 20% критических
            bool isCritical = _random.NextDouble() < 0.2;
            int priority = isCritical ? 100 : 0;
            string taskType = isCritical ? "critical_task" : "regular_task";

            if (isCritical) _criticalCount++;
            else _regularCount++;

            var payload = new
            {
                task_id = Guid.NewGuid(),
                created_at = DateTime.UtcNow,
                priority = priority
            };
            var payloadJson = JsonSerializer.Serialize(payload);

            const string sql = @"
                INSERT INTO tasks (task_type, payload, priority, status, created_at, scheduled_at)
                VALUES (@taskType, @payload::jsonb, @priority, 'Ready', NOW(), NOW())
                RETURNING id";

            await using var cmd = new NpgsqlCommand(sql, connection);
            cmd.Parameters.AddWithValue("@taskType", taskType);
            cmd.Parameters.AddWithValue("@payload", NpgsqlDbType.Jsonb, payloadJson);
            cmd.Parameters.AddWithValue("@priority", priority);

            await cmd.ExecuteScalarAsync(cancellationToken);

            // NOTIFY для пробуждения воркеров
            await using var notifyCmd = new NpgsqlCommand("NOTIFY task_queue, 'new_task'", connection);
            await notifyCmd.ExecuteNonQueryAsync(cancellationToken);

            await transaction.CommitAsync(cancellationToken);

            Console.Write(priority == 100 ? "!" : ".");
        }
        catch (Exception ex)
        {
            await transaction.RollbackAsync(cancellationToken);
            Console.WriteLine($"\n[Producer] Ошибка: {ex.Message}");
        }
    }
}