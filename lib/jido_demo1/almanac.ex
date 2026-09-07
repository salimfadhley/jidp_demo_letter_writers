defmodule JidoDemo1.Almanac do
  @moduledoc """
  What was going on in England, and in each character's own town, in the
  autumn of 1891. The characters all live through the same weeks, but not in
  the same place, so a letter from Bath is written against different local
  news and weather from one written in London on the same day.

  Entries are hand-curated from the historical record rather than generated,
  so the letters stay anchored to things that really happened. Each item has
  the date from which it can be mentioned; standing facts about a place carry
  no date. A prompt receives only items on or before the letter's date, and
  only the most recent few, so the world moves as the correspondence does.
  """

  @type item :: %{date: Date.t() | nil, text: String.t()}

  @doc "A short standing description of a place, as a resident of 1891 would know it."
  @spec place(String.t()) :: String.t()
  def place("Cheltenham") do
    "A Regency spa town under the Cotswold escarpment, genteel and a little faded, full of " <>
      "retired officers and civil servants back from India, with the Promenade and its plane " <>
      "trees, Pittville Pump Room, Montpellier Gardens, the Ladies' College under Miss Beale, " <>
      "and a great many churches. The Gloucestershire Echo prints every evening. Gloucester " <>
      "and the cathedral are eight miles off; London is three hours by the Great Western."
  end

  def place("London") do
    "The capital in the last decade of the century: fog from October, four-wheelers and " <>
      "hansoms, the new deep-level electric railway under the river to Stockwell, Tower Bridge " <>
      "half built with its towers standing bare in the river, Harley Street and the hospitals, " <>
      "the clubs of Pall Mall, Fleet Street and the weekly papers, and the Theosophical " <>
      "headquarters at Avenue Road, St John's Wood, where Madame Blavatsky lived until her death."
  end

  def place("Bath") do
    "The old Georgian spa, quieter than its past: the Abbey, the Pump Room, the Assembly " <>
      "Rooms, terraces of honey-coloured stone climbing the hills, lodging-houses full of " <>
      "invalids and widows. Major Davis's excavations have lately uncovered the Roman Great " <>
      "Bath beside the Pump Room, and the town is arguing about what to build over it. " <>
      "Bristol is a quarter of an hour by rail."
  end

  def place(_other), do: "A town in the south of England."

  @doc "Local items for a place, dated so they can be released as the story's calendar advances."
  @spec local(String.t()) :: [item()]
  def local("Cheltenham") do
    [
      %{
        date: ~D[1891-10-01],
        text:
          "The new Theatre and Opera House in Regent Street opened on the first of October with " <>
            "Mrs. Langtry herself in 'Lady Clancarty'; the town has talked of little else, and " <>
            "the stricter clergy have preached against it."
      },
      %{
        date: ~D[1891-10-05],
        text:
          "The Ladies' College has begun its autumn term; Miss Beale's girls are everywhere " <>
            "on the Promenade in the afternoons."
      },
      %{
        date: ~D[1891-10-10],
        text:
          "The influenza that went through the town last spring is spoken of again, and the " <>
            "doctors are advising the elderly against evening air."
      },
      %{
        date: ~D[1891-10-18],
        text:
          "A lecture on 'Buddhism and the Wisdom of the East' has been advertised at the " <>
            "Assembly Rooms for the end of the month, under Theosophical auspices; " <>
            "the Echo is sceptical."
      },
      %{
        date: ~D[1891-10-24],
        text:
          "Wet and blustery weather; the plane trees on the Promenade are down to bare branches " <>
            "and the Chelt has been over its banks at the bottom of the town."
      },
      %{
        date: ~D[1891-11-01],
        text:
          "All Saints' has been kept with unusual solemnity this year; the churches are full " <>
            "and the talk is of the dead."
      }
    ]
  end

  def local("London") do
    [
      %{
        date: ~D[1891-10-01],
        text:
          "The Strand Magazine's detective stories by Dr. Conan Doyle are the talk of every " <>
            "railway carriage; everyone has an opinion on Mr. Sherlock Holmes."
      },
      %{
        date: ~D[1891-10-06],
        text:
          "Mr. Parnell and Mr. W. H. Smith died on the same day, the sixth; the papers are " <>
            "black-bordered and the Irish question is in every leader."
      },
      %{
        date: ~D[1891-10-12],
        text:
          "The Theosophists at Avenue Road are still in mourning for Madame Blavatsky, dead " <>
            "since May; Mrs. Besant has taken the Lodge in hand and lectures to full rooms."
      },
      %{
        date: ~D[1891-10-15],
        text:
          "The first bad fogs of the season have come down over the river; the hospitals " <>
            "report the usual rise in bronchitis."
      },
      %{
        date: ~D[1891-10-20],
        text:
          "The Society for Psychical Research has issued a new part of its Proceedings; " <>
            "Mr. Myers and Mr. Podmore are again at odds over the evidential value of mediums."
      },
      %{
        date: ~D[1891-10-28],
        text:
          "Tower Bridge's two great piers stand in the river with the towers rising on them; " <>
            "the Pool is a forest of scaffolding and every visitor is taken to see it."
      },
      %{
        date: ~D[1891-11-02],
        text:
          "Mr. Balfour, newly leader in the Commons, is the coming man; the clubs expect a " <>
            "general election next year and are already laying odds."
      }
    ]
  end

  def local("Bath") do
    [
      %{
        date: ~D[1891-10-01],
        text:
          "The excavated Roman Great Bath lies open to the sky beside the Pump Room, green " <>
            "water and broken columns; the Corporation cannot agree what to build over it."
      },
      %{
        date: ~D[1891-10-08],
        text:
          "The season's first invalids have arrived for the waters; the lodging-houses on " <>
            "the hills are filling and the Bath chairs are out on Milsom Street."
      },
      %{
        date: ~D[1891-10-16],
        text:
          "A travelling mesmerist has taken the Assembly Rooms for a week and is drawing " <>
            "crowds; the Bath Chronicle calls it vulgar and prints the programme anyway."
      },
      %{
        date: ~D[1891-10-22],
        text:
          "Heavy rain has swollen the Avon and the lower streets by the river have been " <>
            "flooded again, as they are most autumns."
      },
      %{
        date: ~D[1891-10-30],
        text:
          "Talk in the Pump Room is of Tess, Mr. Hardy's new serial in the Graphic, which " <>
            "the ladies read and say they do not."
      }
    ]
  end

  def local(_other), do: []

  @doc "National and world news, dated, that any educated person would have heard."
  @spec national() :: [item()]
  def national do
    [
      %{
        date: ~D[1891-10-06],
        text:
          "Charles Stewart Parnell died at Brighton on the sixth of October, and on the same " <>
            "day Mr. W. H. Smith, the Leader of the House; the Irish party is in disarray."
      },
      %{
        date: ~D[1891-10-06],
        text:
          "Madame Blavatsky died in London in May; her followers speak of her 'passing', " <>
            "and Mrs. Annie Besant now leads the Theosophical Society in England."
      },
      %{
        date: ~D[1891-10-08],
        text:
          "The Free Education Act came into force in September; the board schools are now " <>
            "free, and the Church papers are uneasy about it."
      },
      %{
        date: ~D[1891-10-12],
        text:
          "The Tranby Croft baccarat affair, with the Prince of Wales in the witness-box " <>
            "last June, is still a joke in the clubs and a scandal in the parsonages."
      },
      %{
        date: ~D[1891-10-14],
        text:
          "Mr. Hardy's 'Tess of the d'Urbervilles' is running in the Graphic, much cut, and " <>
            "'The Picture of Dorian Gray' in book form is still being called immoral."
      },
      %{
        date: ~D[1891-10-20],
        text:
          "The influenza of the last two winters is expected to return with the cold; " <>
            "every household has a story of someone carried off by it."
      },
      %{
        date: ~D[1891-10-26],
        text:
          "The Manchester Ship Canal is still digging its way to the sea; the Naval " <>
            "Exhibition at Chelsea has closed after a summer of enormous crowds."
      },
      %{
        date: ~D[1891-11-01],
        text: "Mr. Balfour has succeeded Mr. Smith as Leader of the House of Commons."
      }
    ]
  end

  @doc """
  The world as one character sees it on one date: their place, the latest
  local items, and the latest national news, all dated on or before `date`.
  """
  @spec context(String.t(), Date.t(), keyword()) :: %{
          place: String.t(),
          local: [String.t()],
          national: [String.t()]
        }
  def context(location, %Date{} = date, opts \\ []) do
    take = Keyword.get(opts, :take, 3)

    %{
      place: place(location),
      local: location |> local() |> released(date, take),
      national: national() |> released(date, take)
    }
  end

  defp released(items, date, take) do
    items
    |> Enum.filter(fn %{date: d} -> is_nil(d) or Date.compare(d, date) != :gt end)
    |> Enum.sort_by(& &1.date, {:asc, Date})
    |> Enum.take(-take)
    |> Enum.map(& &1.text)
  end
end
