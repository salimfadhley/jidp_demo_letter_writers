defmodule Play1.LLM do
  @moduledoc """
  Model-client boundary. The concrete client is chosen by the `:llm_client`
  application setting: `Play1.LLM.OpenRouter` in normal use and
  `Play1.LLM.Stub` under test, so simulations can run deterministically.
  """

  require Logger

  @callback complete(system :: String.t(), user :: String.t(), opts :: keyword()) ::
              {:ok, String.t()} | {:error, term()}

  @doc "Ask the configured client for a completion."
  @spec complete(String.t(), String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def complete(system, user, opts \\ []), do: client().complete(system, user, opts)

  @doc """
  Ask for a completion and decode it as a JSON object.

  Malformed JSON is repaired where possible and otherwise requested again,
  up to `:json_retries` times (default 1).
  """
  @spec complete_json(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def complete_json(system, user, opts \\ []) do
    retries = Keyword.get(opts, :json_retries, 2)

    case complete(system, user, opts) do
      {:ok, text} ->
        case decode_json(text) do
          {:ok, map} ->
            {:ok, map}

          {:error, _} = error when retries <= 0 ->
            error

          {:error, reason} ->
            Logger.warning(
              "Model returned invalid JSON, asking again: #{inspect(reason, limit: 5)}"
            )

            complete_json(system, user, Keyword.put(opts, :json_retries, retries - 1))
        end

      # A reply cut off at the token limit, or empty, is transient: ask again with more room.
      {:error, {kind, _}} when kind in [:truncated, :empty_response] and retries > 0 ->
        bigger = Keyword.get(opts, :max_tokens, 4000) * 2
        Logger.warning("Model reply was #{kind}; asking again with #{bigger} tokens")

        complete_json(
          system,
          user,
          opts |> Keyword.put(:json_retries, retries - 1) |> Keyword.put(:max_tokens, bigger)
        )

      {:error, _} = error ->
        error
    end
  end

  @doc "Decode a JSON object from model output, tolerating code fences and stray prose."
  @spec decode_json(String.t()) :: {:ok, map()} | {:error, term()}
  def decode_json(text) do
    cleaned = text |> String.trim() |> strip_fences()

    candidates =
      [cleaned, repair_control_characters(cleaned)] ++
        case Regex.run(~r/\{.*\}/s, cleaned) do
          [inner] -> [inner, repair_control_characters(inner)]
          nil -> []
        end

    Enum.find_value(candidates, {:error, {:invalid_json, text}}, fn candidate ->
      case Jason.decode(candidate) do
        {:ok, map} when is_map(map) -> {:ok, map}
        _ -> nil
      end
    end)
  end

  @doc """
  Escape raw newlines, carriage returns and tabs that appear inside JSON string
  literals. Models often emit these when a letter body has paragraphs.
  """
  @spec repair_control_characters(String.t()) :: String.t()
  def repair_control_characters(text) do
    text
    |> String.graphemes()
    |> Enum.reduce({[], false, false}, fn char, {acc, in_string?, escaped?} ->
      cond do
        escaped? -> {[char | acc], in_string?, false}
        char == "\\" and in_string? -> {[char | acc], in_string?, true}
        char == "\"" -> {[char | acc], not in_string?, false}
        in_string? and char == "\n" -> {["\\n" | acc], in_string?, false}
        in_string? and char == "\r" -> {["\\r" | acc], in_string?, false}
        in_string? and char == "\t" -> {["\\t" | acc], in_string?, false}
        true -> {[char | acc], in_string?, false}
      end
    end)
    |> elem(0)
    |> Enum.reverse()
    |> IO.iodata_to_binary()
  end

  @doc "The client module currently configured."
  @spec client() :: module()
  def client, do: Application.get_env(:play1, :llm_client, Play1.LLM.OpenRouter)

  defp strip_fences(text) do
    text
    |> String.replace(~r/\A```(?:json)?\s*/i, "")
    |> String.replace(~r/\s*```\z/, "")
  end
end
