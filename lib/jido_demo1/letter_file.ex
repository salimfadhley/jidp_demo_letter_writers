defmodule JidoDemo1.LetterFile do
  @moduledoc "Appends finished letters to a plain-text file, one file per story run."

  @dir "letters"

  @doc "Create a fresh, timestamped correspondence file and return its path."
  @spec new_path() :: Path.t()
  def new_path do
    File.mkdir_p!(@dir)
    now = DateTime.utc_now()
    stamp = Calendar.strftime(now, "%Y%m%d-%H%M%S")
    path = Path.join(@dir, "correspondence-#{stamp}.txt")

    File.write!(path, """
    THE CORRESPONDENCE
    Begun #{DateTime.to_iso8601(now)}

    """)

    path
  end

  @doc "Append one letter, with a header naming the writer and the recipient."
  @spec append(Path.t(), pos_integer(), String.t(), String.t(), String.t()) :: :ok
  def append(path, number, from, to, body) do
    rule = String.duplicate("=", 72)

    File.write!(
      path,
      "#{rule}\nLetter #{number}: from #{from} to #{to}\n#{rule}\n\n#{body}\n\n\n",
      [:append]
    )
  end
end
