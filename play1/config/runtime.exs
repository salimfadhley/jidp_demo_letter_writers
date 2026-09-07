import Config

# Load a local .env file (if present) into the process environment so that the
# OpenRouter key never has to be committed or exported by hand.
env_file = Path.expand("../.env", __DIR__)

if File.exists?(env_file) do
  env_file
  |> File.stream!()
  |> Stream.map(&String.trim/1)
  |> Stream.reject(&(&1 == "" or String.starts_with?(&1, "#")))
  |> Enum.each(fn line ->
    case String.split(line, "=", parts: 2) do
      [key, value] -> System.put_env(String.trim(key), String.trim(value, "\""))
      _ -> :ok
    end
  end)
end

config :play1,
  openrouter_api_key: System.get_env("OPENROUTER_API_KEY"),
  openrouter_model: System.get_env("OPENROUTER_MODEL", "anthropic/claude-sonnet-5")
