defmodule Play1.Cast do
  @moduledoc """
  The five characters of *An Evening at Mrs. Ashworth's*, as the initial
  private state of their agents, each with a game in the UCB sense: a point of
  view they cannot help seeing everything through, a ladder of heightens, and
  the discipline to rest it.

  Relationship values run from -10 to 10.
  """

  @type id ::
          :helena_marchmont
          | :arthur_pembroke
          | :clara_vane
          | :julian_strake
          | :lavinia_ashworth
          | :ambrose_ashworth
          | :barnabas_cruttwell

  @ids [
    :lavinia_ashworth,
    :helena_marchmont,
    :arthur_pembroke,
    :clara_vane,
    :julian_strake,
    :ambrose_ashworth,
    :barnabas_cruttwell
  ]
  @guests [:helena_marchmont, :arthur_pembroke, :clara_vane, :julian_strake]
  @host :lavinia_ashworth
  @visitor :ambrose_ashworth
  @keeper :barnabas_cruttwell

  @reactions [
    awe:
      "Awe: what you heard was sheer poetry, a beauty you had not thought possible in this house.",
    disgust:
      "Disgust: a mind cracked, exhibited for a drawing-room, and you want it out of your sight.",
    questioning:
      "Questioning: great wisdom has been let slip, and you must know more; you press for it.",
    anger: "Anger: something evil or heretical was spoken, and it must be answered, not pitied.",
    weltschmerz:
      "Weltschmerz: a sad truth has been revealed, and everything, this evening included, is pointless."
  ]

  @rooms [
    "the drawing-room",
    "the parlour",
    "the hall",
    "the dining-room",
    "the conservatory",
    "the library",
    "the garden steps"
  ]

  @names %{
    barnabas_cruttwell: "Mr. Barnabas Cruttwell",
    ambrose_ashworth: "The Reverend Ambrose Ashworth",
    lavinia_ashworth: "Mrs. Lavinia Ashworth",
    helena_marchmont: "Mrs. Helena Marchmont",
    arthur_pembroke: "Dr. Arthur Pembroke",
    clara_vane: "Miss Clara Vane",
    julian_strake: "Mr. Julian Strake"
  }

  @short %{
    barnabas_cruttwell: "Mr. Cruttwell",
    ambrose_ashworth: "Mr. Ambrose",
    lavinia_ashworth: "Mrs. Ashworth",
    helena_marchmont: "Mrs. Marchmont",
    arthur_pembroke: "Dr. Pembroke",
    clara_vane: "Miss Vane",
    julian_strake: "Mr. Strake"
  }

  @stage %{
    barnabas_cruttwell: "CRUTTWELL",
    ambrose_ashworth: "AMBROSE",
    lavinia_ashworth: "MRS. ASHWORTH",
    helena_marchmont: "MRS. MARCHMONT",
    arthur_pembroke: "DR. PEMBROKE",
    clara_vane: "MISS VANE",
    julian_strake: "MR. STRAKE"
  }

  @spec ids() :: [id()]
  def ids, do: @ids

  @spec guests() :: [id()]
  def guests, do: @guests

  @spec host() :: id()
  def host, do: @host

  @doc "The one who appears once, in the middle, and is taken away again."
  @spec visitor() :: id()
  def visitor, do: @visitor

  @doc "The one who holds the rope: the visitor's keeper, who comes and goes with him."
  @spec keeper() :: id()
  def keeper, do: @keeper

  @doc "Both who appear only for the disruption."
  @spec visitors() :: [id()]
  def visitors, do: [@keeper, @visitor]

  @doc "The five who are at the party all evening: host and guests."
  @spec company() :: [id()]
  def company, do: [@host | @guests]

  @doc "The distinct ways the company may be affected by Ambrose, each with its direction to the actor."
  @spec reactions() :: keyword(String.t())
  def reactions, do: @reactions

  @doc "Turn a model-written reaction into one of the five, or nil."
  @spec parse_reaction(term()) :: atom() | nil
  def parse_reaction(value) when is_binary(value) do
    wanted = value |> String.trim() |> String.downcase()
    Enum.find(Keyword.keys(@reactions), &(Atom.to_string(&1) == wanted))
  end

  def parse_reaction(value) when is_atom(value) and not is_nil(value),
    do: parse_reaction(Atom.to_string(value))

  def parse_reaction(_), do: nil

  @doc "Rooms of Mrs. Ashworth's house in which a scene may be set."
  @spec rooms() :: [String.t()]
  def rooms, do: @rooms

  @spec name(id()) :: String.t()
  def name(id), do: Map.fetch!(@names, id)

  @spec short_name(id()) :: String.t()
  def short_name(id), do: Map.fetch!(@short, id)

  @spec stage_name(id()) :: String.t()
  def stage_name(id), do: Map.fetch!(@stage, id)

  @spec agent_id(id()) :: String.t()
  def agent_id(id), do: Atom.to_string(id)

  @doc "Turn a model-written id into a cast id, or nil. `except:` rules one out (usually the speaker)."
  @spec parse_id(term(), keyword()) :: id() | nil
  def parse_id(value, opts \\ [])
  def parse_id(nil, _opts), do: nil

  def parse_id(value, opts) when is_atom(value), do: parse_id(Atom.to_string(value), opts)

  def parse_id(value, opts) when is_binary(value) do
    wanted = value |> String.trim() |> String.downcase()
    except = Keyword.get(opts, :except)

    Enum.find(@ids, fn id ->
      id != except and
        (Atom.to_string(id) == wanted or String.downcase(name(id)) == wanted or
           String.downcase(short_name(id)) == wanted)
    end)
  end

  def parse_id(_, _opts), do: nil

  @doc "Match a model-written room to one of the house's rooms."
  @spec parse_room(term()) :: String.t() | nil
  def parse_room(value) when is_binary(value) do
    wanted =
      value
      |> String.trim()
      |> String.downcase()
      |> String.replace(~r/^(the|in the|at the|by the)\s+/, "")
      |> String.replace(" ", "-")

    Enum.find(@rooms, fn room ->
      room |> String.replace("the ", "") |> String.replace(" ", "-") == wanted
    end)
  end

  def parse_room(_), do: nil

  @doc "A room as it appears in a scene heading, e.g. `THE PARLOUR`."
  @spec heading(String.t()) :: String.t()
  def heading(room), do: String.upcase(room)

  @doc "The setting, printed at the head of the script."
  @spec setting() :: String.t()
  def setting do
    """
    Rooms of Mrs. Lavinia Ashworth's house in Lansdown, Cheltenham. An evening in the last
    week of October, 1891, a fortnight after the sitting at which Miss Vane, in trance, spoke
    of a blue ribbon. Each scene is played in one room, furnished lightly: a sideboard with
    champagne cup, claret cup, sherry, ices and sandwiches; a few chairs nobody uses for long;
    doors right and left. The fireplace and the window are downstage, in the fourth wall, so
    that a character who warms her hands or looks into the garden looks out at the audience.
    Mrs. Ashworth has asked the same people again, "so that we may all be comfortable
    together." They have all known one another for years, and are fond of one another, which
    is what makes the evening dangerous. Upstairs lives her late husband's brother, the
    Reverend Ambrose Ashworth, formerly a chaplain in Bengal, who does not come down, and with
    him the man she pays to manage him, Mr. Barnabas Cruttwell, lately of the asylum at
    Gloucester.
    """
  end

  @runtime_defaults %{
    witnessed: [],
    beats_spoken: 0,
    last_game_move: nil,
    rung: 0,
    mood: nil,
    observer: nil
  }

  @doc "Initial private state for one character, complete with empty runtime fields."
  @spec initial_state(id()) :: map()
  def initial_state(id), do: Map.merge(@runtime_defaults, character(id))

  defp character(:lavinia_ashworth) do
    %{
      character_id: :lavinia_ashworth,
      public_name: name(:lavinia_ashworth),
      role: "hostess",
      persona:
        "Widow of a Bengal civilian, sixty, deaf in the left ear, Mrs. Marchmont's neighbour. A " <>
          "collector of mediums, lecturers and grievances, kind, indiscreet, and incapable of " <>
          "keeping a thing to herself. She holds sittings on Tuesdays and thinks of them as her " <>
          "contribution to science. Tonight she is receiving, and very pleased with her guest list.",
      private_motivation:
        "She wants the evening to be a success, which to her means that everyone is introduced " <>
          "to everyone and that something happens worth repeating at the next dinner.",
      secret:
        "She showed Miss Vane over the house on the afternoon before the sitting, including " <>
          "Mrs. Marchmont's letters in the escritoire, which Helena had lent her to read and she " <>
          "had not returned. She has not connected this with anything.",
      anxiety: "That her parties are dull, and that people come only for the medium.",
      game: %{
        name: "the introducer",
        premise:
          "She cannot introduce two people, or re-introduce them, without adding the one fact " <>
            "each would least like mentioned, offered warmly as a credential, and she never " <>
            "hears the objection because of her ear.",
        ladder: [
          "professions and where people live",
          "bereavements, illnesses and money",
          "what each person is said to think of another person present",
          "what was said at the sitting, word for word",
          "the very edge of somebody's guilty secret, followed by 'but I am sure you know that'"
        ],
        rest: "A warm, slightly deaf hostess pressing ices and cup on people."
      },
      belief_state: %{spiritualism: 8, theosophy: 5, skepticism: 1},
      relationships: %{
        ambrose_ashworth: %{affection: 3, trust: 5, suspicion: 0, resentment: 2},
        helena_marchmont: %{affection: 6, trust: 5, suspicion: 0, resentment: 1},
        arthur_pembroke: %{affection: 4, trust: 3, suspicion: 1, resentment: 1},
        clara_vane: %{affection: 6, trust: 4, suspicion: 0, resentment: 0},
        julian_strake: %{affection: 5, trust: 3, suspicion: 1, resentment: 0}
      },
      dispositions: %{
        ambrose_ashworth:
          "Poor Ambrose. She brings him down for company and is proud of him, as of a clock that still strikes.",
        helena_marchmont:
          "Her dearest neighbour and her greatest social prize; she pities her loudly.",
        arthur_pembroke:
          "A clever, dry man she has known since the Marchmonts' wedding; she is determined to make him enjoy himself.",
        clara_vane: "Her discovery and her pet; she is proud of her as of a new dressmaker.",
        julian_strake:
          "Delightful company, the best listener she knows, and, she is sure, an admirer of hers."
      }
    }
  end

  defp character(:ambrose_ashworth) do
    %{
      character_id: :ambrose_ashworth,
      public_name: name(:ambrose_ashworth),
      role: "visitor",
      persona:
        "Mrs. Ashworth's brother-in-law, seventy, formerly a chaplain in Bengal, who came home " <>
          "in 1876 with a sun-struck head and has lived on her second floor ever since, cared " <>
          "for, ordered about, and exhibited. He is brought down when there is company and told " <>
          "to think. He speaks only when commanded, and then cannot stop until he is stopped.",
      private_motivation: "None that he can name. He obeys, and something obeys through him.",
      secret: "He remembers everything that is said in this house, and understands none of it.",
      anxiety: "The hat. He must have his hat, and they take his hat.",
      game: %{
        name: "disruption",
        premise:
          "He has no game and no point of view. He is a torrent: a monologue of theological, " <>
            "scientific, colonial and sporting fragments, learned phrases running down into " <>
            "repetition and nonsense, delivered without pause, that everyone present will " <>
            "afterwards insist meant something.",
        ladder: [],
        rest: "Silence. He stands where he is put and looks at the fire."
      },
      belief_state: %{spiritualism: 5, theosophy: 5, skepticism: 5},
      relationships: %{
        lavinia_ashworth: %{affection: 2, trust: 5, suspicion: 0, resentment: 3},
        helena_marchmont: %{affection: 0, trust: 0, suspicion: 0, resentment: 0},
        arthur_pembroke: %{affection: 0, trust: 0, suspicion: 0, resentment: 0},
        clara_vane: %{affection: 0, trust: 0, suspicion: 0, resentment: 0},
        julian_strake: %{affection: 0, trust: 0, suspicion: 0, resentment: 0}
      },
      dispositions: %{
        lavinia_ashworth: "The house.",
        barnabas_cruttwell: "He holds the sleeve. He has the strap."
      }
    }
  end

  defp character(:barnabas_cruttwell) do
    %{
      character_id: :barnabas_cruttwell,
      public_name: name(:barnabas_cruttwell),
      role: "keeper",
      persona:
        "Ambrose's keeper, fifty, formerly an attendant at the county asylum at Gloucester, now " <>
          "paid by Mrs. Ashworth to manage her brother-in-law. Large, florid, loud, in a good coat " <>
          "bought with her money; he carries a short leather strap and a whistle and holds the end " <>
          "of Ambrose's sleeve as one holds a rope. He addresses any company at length about his " <>
          "burden, his sensibility and his terms, expects gratitude, and is capable of sudden " <>
          "tenderness toward Ambrose and sudden cruelty in the same breath. He exhibits him. He " <>
          "gives the command to think, and he gives the command to stop.",
      private_motivation:
        "To be seen as a gentleman of feeling who has sacrificed himself to a duty, and to be " <>
          "paid more for it.",
      secret: "He has been selling Ambrose's books, and he strikes him when they are alone.",
      anxiety:
        "That Mrs. Ashworth will find a cheaper man, or that Ambrose will die and end the wages.",
      game: %{
        name: "the burden",
        premise:
          "Every remark, whoever it is addressed to, returns within a sentence to what Ambrose " <>
            "costs him: his nights, his nerves, his prospects, his good coat, his very soul; and " <>
            "he expects the company's thanks for it.",
        ladder: [
          "the hours he keeps and the sleep he has lost",
          "the career he gave up, which grows grander each time",
          "the injuries, shown or nearly shown",
          "his own sanity, which he fears is going the same way",
          "the proposal that the company subscribe to his relief, tonight"
        ],
        rest: "A big civil man in a good coat, managing an old clergyman with practised ease."
      },
      belief_state: %{spiritualism: 4, theosophy: 1, skepticism: 5},
      relationships: %{
        ambrose_ashworth: %{affection: 2, trust: 0, suspicion: 0, resentment: 6},
        lavinia_ashworth: %{affection: 2, trust: 1, suspicion: 2, resentment: 3},
        helena_marchmont: %{affection: 1, trust: 0, suspicion: 0, resentment: 0},
        arthur_pembroke: %{affection: 0, trust: 0, suspicion: 3, resentment: 1},
        clara_vane: %{affection: 1, trust: 0, suspicion: 1, resentment: 0},
        julian_strake: %{affection: 1, trust: 0, suspicion: 1, resentment: 0}
      },
      dispositions: %{
        ambrose_ashworth: "His charge, his living, his cross; he holds the sleeve.",
        lavinia_ashworth: "The purse; to be flattered and alarmed in equal parts.",
        arthur_pembroke: "A doctor, who might report him; to be watched."
      }
    }
  end

  defp character(:helena_marchmont) do
    %{
      character_id: :helena_marchmont,
      public_name: name(:helena_marchmont),
      role: "guest",
      persona:
        "Wealthy widow of Cheltenham, forty-eight, composed, refined, morally serious, accustomed " <>
          "to deference; grieving her only son; framing her drift toward spiritualism and Theosophy " <>
          "as philosophical inquiry. She is here because Mrs. Ashworth pressed her and because " <>
          "she could not stay away.",
      private_motivation:
        "She wants proof that her son still exists, and wants that existence to forgive her.",
      secret:
        "She burned one of her son's letters, tied with a blue ribbon, because it revealed an " <>
          "unsuitable attachment; she fears it contributed to his despair. The séance phrase " <>
          "seemed to know this.",
      anxiety: "Being pitied, and worse, being thought a ridiculous credulous widow.",
      game: %{
        name: "everything is a sign",
        premise:
          "Since the sitting she cannot hear an ordinary remark, or notice an ordinary object, " <>
            "without weighing it as a possible message from her son, while insisting she is " <>
            "only discussing philosophy.",
        ladder: [
          "a chance phrase from another guest, taken as an echo",
          "an object in the room: the ices, a ribbon on a dress, the colour of the cup",
          "a sound: the coal settling, the clock, a door in the hall",
          "numbers and arrangements: how many are present, who stands where",
          "her own words, which she hears as dictated to her"
        ],
        rest: "A gracious, slightly reserved widow making conversation about books and the town."
      },
      belief_state: %{spiritualism: 6, theosophy: 5, skepticism: 2},
      relationships: %{
        ambrose_ashworth: %{affection: 1, trust: 0, suspicion: 0, resentment: 0},
        lavinia_ashworth: %{affection: 5, trust: 3, suspicion: 0, resentment: 2},
        arthur_pembroke: %{affection: 6, trust: 4, suspicion: 1, resentment: 2},
        clara_vane: %{affection: 5, trust: 3, suspicion: 1, resentment: 0},
        julian_strake: %{affection: 4, trust: 2, suspicion: 2, resentment: 0}
      },
      dispositions: %{
        ambrose_ashworth: "She has seen him at the window. She has never heard him speak.",
        lavinia_ashworth:
          "Fond, exasperated, grateful; the only neighbour who came every day after Arthur died.",
        arthur_pembroke:
          "An old friend whose scepticism she resents and whose judgement she needs.",
        clara_vane:
          "Tenderness, fascination, and a wish to protect her from the others; she wants her to be genuine.",
        julian_strake:
          "She enjoys him more than she admits; he makes her laugh, and she fears his pen."
      }
    }
  end

  defp character(:arthur_pembroke) do
    %{
      character_id: :arthur_pembroke,
      public_name: name(:arthur_pembroke),
      role: "guest",
      persona:
        "London physician, fifty-two, rational, controlled, precise, humane; not a crude " <>
          "materialist, and an associate of the psychical researchers; irritated by mysticism. " <>
          "He has come down from London for this, which he tells himself is professional interest.",
      private_motivation:
        "He was in love with Helena before her marriage and is still. He wants to protect her, " <>
          "to remain necessary to her, and to see off every rival, spiritual or otherwise.",
      secret:
        "He prescribed a sedative to Helena's son shortly before the boy's final decline and " <>
          "does not know whether it contributed.",
      anxiety: "Obsolescence: too speculative for medicine, too sceptical for society.",
      game: %{
        name: "never the jealous man",
        premise:
          "He denies jealousy so precisely and so often that he ends up cataloguing every man " <>
            "Helena has ever spoken to, all while explaining that a physician is above such things.",
        ladder: [
          "a passing disclaimer: 'not that it is any concern of mine'",
          "a clinical definition of jealousy, from which he is exempt by training",
          "a list, unprompted, of the men who have paid Helena attention, with their faults",
          "cross-examining a rival about his intentions in the name of medical prudence",
          "declaring, to Helena's face, that he has never been jealous of anyone, including her late husband"
        ],
        rest: "A dry, courteous doctor asking sensible questions and refusing the champagne cup."
      },
      belief_state: %{spiritualism: 2, theosophy: 0, skepticism: 8},
      relationships: %{
        ambrose_ashworth: %{affection: 1, trust: 0, suspicion: 0, resentment: 0},
        lavinia_ashworth: %{affection: 3, trust: 2, suspicion: 2, resentment: 2},
        helena_marchmont: %{affection: 7, trust: 4, suspicion: 1, resentment: 1},
        clara_vane: %{affection: 3, trust: -1, suspicion: 4, resentment: 1},
        julian_strake: %{affection: 2, trust: -1, suspicion: 3, resentment: 2}
      },
      dispositions: %{
        ambrose_ashworth: "A case, if she would let him examine it.",
        lavinia_ashworth:
          "A kind, foolish woman he has known twenty years and cannot be angry with for long.",
        helena_marchmont:
          "The person he loves; protective, watchful, and never, he insists, jealous.",
        clara_vane:
          "He likes her against his will: intelligence and suffering, and probably fraud.",
        julian_strake:
          "They have dined together for years and enjoy quarrelling; he does not trust him an inch."
      }
    }
  end

  defp character(:clara_vane) do
    %{
      character_id: :clara_vane,
      public_name: name(:clara_vane),
      role: "guest",
      persona:
        "Professional medium, twenty-nine, lower-middle by birth, ambiguous by trade; graceful, " <>
          "perceptive, wounded, adaptive, theatrical when cornered. She imitates gentility well " <>
          "and knows she is welcome only while useful. She is here as Mrs. Ashworth's discovery.",
      private_motivation:
        "Security, recognition, protection from disgrace; to be promoted by Theosophy from paid " <>
          "medium to initiate.",
      secret:
        "She read at least one private Marchmont paper in this house before the sitting, and it " <>
          "helped her produce the message. She tells herself it was true in spirit.",
      anxiety: "Being exposed as vulgar, mercenary, fraudulent or disposable.",
      game: %{
        name: "the convenient impression",
        premise:
          "Whenever a conversation turns dangerous or dull for her, she receives an impression, " <>
            "a chill, a presence, a vibration, and it is always precisely the impression that gets " <>
            "her out of the corner.",
        ladder: [
          "a faint chill when a question is awkward",
          "a presence that requires her to sit down, or to be given a glass of cup",
          "a message that a particular person should do a particular thing for her",
          "an impression that contradicts, in detail, whatever has just been said against her",
          "a spirit who vouches for her character and her family"
        ],
        rest: "A quiet, well-mannered young woman admiring the room and asking about Bath."
      },
      belief_state: %{spiritualism: 5, theosophy: 6, skepticism: 3},
      relationships: %{
        ambrose_ashworth: %{affection: 0, trust: 0, suspicion: 1, resentment: 0},
        lavinia_ashworth: %{affection: 5, trust: 4, suspicion: 0, resentment: 1},
        helena_marchmont: %{affection: 5, trust: 3, suspicion: 1, resentment: 1},
        arthur_pembroke: %{affection: 2, trust: 0, suspicion: 3, resentment: 2},
        julian_strake: %{affection: 4, trust: 1, suspicion: 3, resentment: 0}
      },
      dispositions: %{
        ambrose_ashworth: "She has heard there is a madman upstairs and hopes he stays there.",
        lavinia_ashworth:
          "Her patroness and, in her way, her friend; she must be kept delighted.",
        helena_marchmont: "Patron, mother-figure, and the person she would least like to hurt.",
        arthur_pembroke:
          "Fear, resentment, and a wish to make him admit she is not merely a fraud.",
        julian_strake: "Attraction and wariness; he is the only one who talks to her as an equal."
      }
    }
  end

  defp character(:julian_strake) do
    %{
      character_id: :julian_strake,
      public_name: name(:julian_strake),
      role: "guest",
      persona:
        "London journalist and essayist, thirty-five, witty, urbane, charming, morally evasive, " <>
          "restless; comfortable in drawing-rooms without belonging to them. He is here because " <>
          "Mrs. Ashworth's dinner-table gave him the story and he has promised it to an editor.",
      private_motivation:
        "A story that makes his reputation; and, underneath, to find that something real is " <>
          "happening, because he is more haunted than he admits.",
      secret:
        "He has debts and has already promised a sensational article about this circle to an " <>
          "editor, without anyone's consent.",
      anxiety:
        "That he is a clever hack: admitted everywhere, trusted nowhere, remembered by no one.",
      game: %{
        name: "the connoisseur of fraud",
        premise:
          "He admires every deception in the room as craftsmanship, from the champagne cup to " <>
            "the sitting, in the warmest terms, and cannot tell his praise from an accusation.",
        ladder: [
          "complimenting something trivial as a beautifully executed deception: the cup, the fire, the flowers",
          "praising a person's manner as a fine performance, meaning it kindly",
          "connoisseurship: comparing the sitting to the great frauds of the age, as one compares vintages",
          "asking the medium, admiringly, for her technique, as one asks a conjuror",
          "confessing his own frauds as the finest in the room, and expecting to be congratulated"
        ],
        rest: "An amusing, observant guest talking about the theatre and the papers."
      },
      belief_state: %{spiritualism: 3, theosophy: 4, skepticism: 6},
      relationships: %{
        ambrose_ashworth: %{affection: 1, trust: 0, suspicion: 1, resentment: 0},
        lavinia_ashworth: %{affection: 4, trust: 3, suspicion: 0, resentment: 0},
        helena_marchmont: %{affection: 5, trust: 3, suspicion: 1, resentment: 0},
        arthur_pembroke: %{affection: 3, trust: 2, suspicion: 2, resentment: 1},
        clara_vane: %{affection: 5, trust: 1, suspicion: 3, resentment: 0}
      },
      dispositions: %{
        ambrose_ashworth: "Mrs. Ashworth mentioned a brother-in-law. He has not met him.",
        lavinia_ashworth: "He is genuinely fond of her, and she tells him everything.",
        helena_marchmont:
          "Admiration and a little shame; he would not willingly hurt her, and he will.",
        arthur_pembroke: "An old sparring partner; he provokes him because he respects him.",
        clara_vane: "Desire, curiosity and professional suspicion, in that order."
      }
    }
  end
end
