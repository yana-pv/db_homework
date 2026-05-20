namespace TaskQueueSystem;

public class DatabaseConfig
{
    public string Host { get; set; } = "localhost";
    public int Port { get; set; } = 5438;
    public string Username { get; set; } = "admin";
    public string Password { get; set; } = "admin"; 
    public string Database { get; set; } = "autoservice";

    public string GetConnectionString() =>
        $"Host={Host};Port={Port};Username={Username};Password={Password};Database={Database}";
}