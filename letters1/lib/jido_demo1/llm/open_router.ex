defmodule JidoDemo1.LLM.OpenRouter do
  @moduledoc """
  OpenRouter chat-completions client built on Req.

  The API key and default model come from application config, which
  `config/runtime.exs` populates from the environment (or a local `.env`).
  """

  @behaviour JidoDemo1.LLM

  require Logger

  @url "https://openrouter.ai/api/v1/chat/completions"

  @impl true
  def complete(system, user, opts \\ []) do
    with {:ok, key} <- api_key() do
      body = %{
        model: Keyword.get(opts, :model, default_model()),
        messages: [%{role: "system", content: system}, %{role: "user", content: user}],
        temperature: Keyword.get(opts, :temperature, 0.9),
        max_tokens: Keyword.get(opts, :max_tokens, 4000)
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
          content = choice |> get_in(["message", "content"]) |> to_string() |> String.trim()

          case {choice["finish_reason"], content} do
            {"length", _} ->
              Logger.error("OpenRouter response was cut off at the token limit")
              {:error, {:truncated, content}}

            {_, ""} ->
              Logger.error("OpenRouter returned an empty message: #{inspect(choice)}")
              {:error, {:empty_response, choice}}

            _ ->
              {:ok, content}
          end

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
