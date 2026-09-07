defmodule JidoDemo1.OpenRouter do
  @moduledoc """
  Minimal OpenRouter chat-completions client built on Req.

  The API key and default model come from application config, which
  `config/runtime.exs` populates from the environment (or a local `.env`).
  """

  require Logger

  @url "https://openrouter.ai/api/v1/chat/completions"

  @type message :: %{role: String.t(), content: String.t()}

  @doc """
  Send a chat completion request and return the assistant's reply text.

  `system` is the system prompt; `messages` is the conversation so far.
  Options: `:model`, `:temperature`, `:max_tokens`.
  """
  @spec chat(String.t(), [message()], keyword()) :: {:ok, String.t()} | {:error, term()}
  def chat(system, messages, opts \\ []) do
    with {:ok, key} <- api_key() do
      model = Keyword.get(opts, :model, default_model())

      body = %{
        model: model,
        messages: [%{role: "system", content: system} | messages],
        temperature: Keyword.get(opts, :temperature, 0.9),
        max_tokens: Keyword.get(opts, :max_tokens, 800)
      }

      request =
        Req.new(
          url: @url,
          json: body,
          auth: {:bearer, key},
          headers: [
            {"http-referer", "https://github.com/salimfadhley/jido_demo1"},
            {"x-title", "jido_demo1"}
          ],
          receive_timeout: 120_000,
          retry: :transient,
          max_retries: 2
        )

      case Req.post(request) do
        {:ok, %Req.Response{status: 200, body: %{"choices" => [choice | _]}}} ->
          {:ok, choice |> get_in(["message", "content"]) |> to_string() |> String.trim()}

        {:ok, %Req.Response{status: status, body: body}} ->
          Logger.error("OpenRouter returned HTTP #{status}: #{inspect(body)}")
          {:error, {:http, status, body}}

        {:error, reason} ->
          Logger.error("OpenRouter request failed: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  @doc "The model used when none is given explicitly."
  @spec default_model() :: String.t()
  def default_model do
    Application.get_env(:jido_demo1, :openrouter_model, "anthropic/claude-sonnet-5")
  end

  defp api_key do
    case Application.get_env(:jido_demo1, :openrouter_api_key) do
      key when is_binary(key) and key != "" -> {:ok, key}
      _ -> {:error, :missing_openrouter_api_key}
    end
  end
end
