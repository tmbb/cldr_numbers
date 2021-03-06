defmodule Cldr.Number.Format do
  @moduledoc """
  Functions to manage the collection of number patterns defined in Cldr.

  Number patterns affect how numbers are interpreted in a localized context.
  Here are some examples, based on the French locale. The "." shows where the
  decimal point should go. The "," shows where the thousands separator should
  go. A "0" indicates zero-padding: if the number is too short, a zero (in the
  locale's numeric set) will go there. A "#" indicates no padding: if the
  number is too short, nothing goes there. A "¤" shows where the currency sign
  will go. The following illustrates the effects of different patterns for the
  French locale, with the number "1234.567". Notice how the pattern characters
  ',' and '.' are replaced by the characters appropriate for the locale.

  ## Number Pattern Examples

  | Pattern	      | Currency	      | Text        |
  | ------------- | :-------------: | ----------: |
  | #,##0.##	    | n/a	            | 1 234,57    |
  | #,##0.###	    | n/a	            | 1 234,567   |
  | ###0.#####	  | n/a	            | 1234,567    |
  | ###0.0000#	  | n/a	            | 1234,5670   |
  | 00000.0000	  | n/a	            | 01234,5670  |
  | #,##0.00 ¤	  | EUR	            | 1 234,57 €  |

  The number of # placeholder characters before the decimal do not matter,
  since no limit is placed on the maximum number of digits. There should,
  however, be at least one zero some place in the pattern. In currency formats,
  the number of digits after the decimal also do not matter, since the
  information in the supplemental data (see Supplemental Currency Data) is used
  to override the number of decimal places — and the rounding — according to
  the currency that is being formatted. That can be seen in the above chart,
  with the difference between Yen and Euro formatting.

  Details of the number formats are described in the
  [Unicode documentation](http://unicode.org/reports/tr35/tr35-numbers.html#Number_Format_Patterns)
  """

  @type format :: String.t
  @short_format_styles [:decimal_long, :decimal_short, :currency_short,
                        :currency_long]

  @format_styles       [:standard, :currency, :accounting, :scientific,
                        :percent] ++ @short_format_styles

  defstruct @format_styles ++ [:currency_spacing]

  require Cldr
  alias Cldr.Number.System
  alias Cldr.Locale
  alias Cldr.LanguageTag

  def short_format_styles do
    @short_format_styles
  end

  @doc """
  Returns the list of decimal formats in the configured locales including
  the list of locales configured for precompilation in `config.exs`.

  This function exists to allow the decimal formatter
  to precompile all the known formats at compile time.

  ## Example

      Cldr.Number.Format.decimal_format_list ["#", "#,##,##0%",
      #=> "#,##,##0.###", "#,##,##0.00¤", "#,##,##0.00¤;(#,##,##0.00¤)",
      "#,##,##0 %", "#,##0%", "#,##0.###", "#,##0.00 ¤",
      "#,##0.00 ¤;(#,##0.00 ¤)", "#,##0.00¤", "#,##0.00¤;(#,##0.00¤)",
      "#,##0 %", "#0%", "#0.######", "#0.00 ¤", "#E0", "%#,##0", "% #,##0",
      "0", "0.000000E+000", "0000 M ¤", "0000¤", "000G ¤", "000K ¤", "000M ¤",
      "000T ¤", "000mM ¤", "000m ¤", "000 Bio'.' ¤", "000 Bln ¤", "000 Bn ¤",
      "000 B ¤", "000 E ¤", "000 K ¤", "000 MRD ¤", "000 Md ¤", "000 Mio'.' ¤",
      "000 Mio ¤", "000 Mld ¤", "000 Mln ¤", "000 Mn ¤", "000 Mrd'.' ¤",
      "000 Mrd ¤", "000 Mr ¤", "000 M ¤", "000 NT ¤", "000 N ¤", "000 Tn ¤",
      "000 Tr ¤", ...]
  """
  format_list =
    Cldr.known_locales()
    |> Enum.map(&Cldr.Config.decimal_formats_for/1)
    |> Kernel.++(Cldr.Config.get_precompile_number_formats)
    |> List.flatten
    |> Enum.uniq
    |> Enum.reject(&is_nil/1)
    |> Enum.sort

  @spec decimal_format_list :: [format, ...]
  def decimal_format_list do
    unquote(Macro.escape(format_list))
  end

  @doc """
  Returns the list of decimal formats for a configured locale.

  * `locale` is any locale configured in the system.  See `Cldr.known_locales/0`

  This function exists to allow the decimal formatter to precompile all
  the known formats at compile time. Its use is not otherwise recommended.

  ## Example

      iex> Cldr.Number.Format.decimal_format_list_for Cldr.Locale.new("en")
      ["#,##0%", "#,##0.###", "#E0", "0 billion", "0 million", "0 thousand",
       "0 trillion", "00 billion", "00 million", "00 thousand", "00 trillion",
       "000 billion", "000 million", "000 thousand", "000 trillion", "000B", "000K",
       "000M", "000T", "00B", "00K", "00M", "00T", "0B", "0K", "0M", "0T",
       "¤#,##0.00", "¤#,##0.00;(¤#,##0.00)", "¤000B", "¤000K", "¤000M",
       "¤000T", "¤00B", "¤00K", "¤00M", "¤00T", "¤0B", "¤0K", "¤0M", "¤0T"]

  """
  @spec decimal_format_list_for(LanguageTag.t) :: [String.t, ...]
  def decimal_format_list_for(locale \\ Cldr.get_current_locale())

  for locale_name <- Cldr.Config.known_locales() do
    decimal_formats = Cldr.Config.decimal_formats_for(locale_name)

    def decimal_format_list_for(%LanguageTag{cldr_locale_name: unquote(locale_name)}) do
      unquote(Macro.escape(decimal_formats))
    end
  end

  @doc """
  The decimal formats defined for a given locale or
  for a given locale and number system.

  * `locale` is any locale configured in the system.  See `Cldr.known_locales/0`

  ## Examples

      Cldr.Number.Format.all_formats_for("en")
      #=> %{latn: %Cldr.Number.Format{
        accounting: "¤#,##0.00;(¤#,##0.00)",
        currency: "¤#,##0.00",
        percent: "#,##0%",
        scientific: "#E0",
        standard: "#,##0.###",
        currency_short: [{"1000", [one: "¤0K", other: "¤0K"]},
         {"10000", [one: "¤00K", other: "¤00K"]},
         {"100000", [one: "¤000K", other: "¤000K"]},
         {"1000000", [one: "¤0M", other: "¤0M"]},
         {"10000000", [one: "¤00M", other: "¤00M"]},
         {"100000000", [one: "¤000M", other: "¤000M"]},
         {"1000000000", [one: "¤0B", other: "¤0B"]},
         {"10000000000", [one: "¤00B", other: "¤00B"]},
         {"100000000000", [one: "¤000B", other: "¤000B"]},
         {"1000000000000", [one: "¤0T", other: "¤0T"]},
         {"10000000000000", [one: "¤00T", other: "¤00T"]},
         {"100000000000000", [one: "¤000T", other: "¤000T"]}],
         ....
        }
  """
  @spec all_formats_for(LanguageTag.t) :: Map.t
  def all_formats_for(locale \\ Cldr.get_current_locale())

  @doc """
  Returns the minium grouping digits for a locale.

  * `locale` is any locale configured in the system.  See `Cldr.known_locales/0`

  ## Examples

      iex> Cldr.Number.Format.minimum_grouping_digits_for(Cldr.Locale.new("en"))
      1

  """
  @spec minimum_grouping_digits_for(LanguageTag.t) :: non_neg_integer
  def minimum_grouping_digits_for(locale \\ Cldr.get_current_locale)

  for locale_name <- Cldr.Config.known_locales() do
    locale_data =
      locale_name
      |> Cldr.Config.get_locale

    number_formats =
      locale_data
      |> Map.get(:number_formats)

    minimum_grouping_digits =
      locale_data
      |> Map.get(:minimum_grouping_digits)

    def all_formats_for(%LanguageTag{cldr_locale_name: unquote(locale_name)}) do
      unquote(Macro.escape(number_formats))
    end

    def minimum_grouping_digits_for(%LanguageTag{cldr_locale_name: unquote(locale_name)}) do
      unquote(minimum_grouping_digits)
    end
  end

  def all_formats_for(%LanguageTag{} = locale) do
    {:error, Locale.locale_error(locale)}
  end

  def minimum_grouping_digits_for(%LanguageTag{} = locale) do
    {:error, Locale.locale_error(locale)}
  end

  @doc """
  Returns the minium grouping digits for a locale or raises if there is an error.

  * `locale` is any locale configured in the system.  See `Cldr.known_locales/0`

  ## Examples

      iex> Cldr.Number.Format.minimum_grouping_digits_for!(Cldr.Locale.new("en"))
      1

      Cldr.Number.Format.minimum_grouping_digits_for!(Cldr.Locale.new("end"))
      ** (Cldr.UnknownLocaleError) The locale "end" is not known

  """
  def minimum_grouping_digits_for!(locale) do
    case minimum_grouping_digits_for(locale) do
      {:error, {exception, message}} ->
        raise exception, message
      digits ->
        digits
    end
  end

  @doc """
  Return the predfined formats for a given `locale` and `number_system`.

  * `locale` is any locale configured in the system.  See `Cldr.known_locales/0`

  * `number_system` is either:

    * an `atom` in which case it is interpreted as a `number system type`
    in the given locale.  Typically this would be either `:default` or
    `:native`. See `Cldr.Number.Format.format_types_for/1` for the number
    system types available for a given `locale`.

    * a `binary` in which case it is used to look up the number system
    directly (for exmple `"latn"` which is common for western european
    languages). See `Cldr.Number.Format.formats_for/1` for the
    available formats for a `locale`.

  ## Example

      Cldr.Number.Format.formats_for "fr", :native
      #=> %Cldr.Number.Format{
        accounting: "#,##0.00 ¤;(#,##0.00 ¤)",
        currency: "#,##0.00 ¤",
        percent: "#,##0 %",
        scientific: "#E0",
        standard: "#,##0.###"
        currency_short: [{"1000", [one: "0 k ¤", other: "0 k ¤"]},
         {"10000", [one: "00 k ¤", other: "00 k ¤"]},
         {"100000", [one: "000 k ¤", other: "000 k ¤"]},
         {"1000000", [one: "0 M ¤", other: "0 M ¤"]},
         {"10000000", [one: "00 M ¤", other: "00 M ¤"]},
         {"100000000", [one: "000 M ¤", other: "000 M ¤"]},
         {"1000000000", [one: "0 Md ¤", other: "0 Md ¤"]},
         {"10000000000", [one: "00 Md ¤", other: "00 Md ¤"]},
         {"100000000000", [one: "000 Md ¤", other: "000 Md ¤"]},
         {"1000000000000", [one: "0 Bn ¤", other: "0 Bn ¤"]},
         {"10000000000000", [one: "00 Bn ¤", other: "00 Bn ¤"]},
         {"100000000000000", [one: "000 Bn ¤", other: "000 Bn ¤"]}],
         ...
        }

  """
  @spec formats_for(LanguageTag.t, atom | String.t) :: Map.t
  def formats_for(locale \\ Cldr.get_current_locale(), number_system \\ :default)

  def formats_for(%LanguageTag{} = locale, number_system) do
    with {:ok, _} <- Cldr.validate_locale(locale),
         {:ok, system_name} <- System.system_name_from(number_system, locale)
    do
      formats =
        locale
        |> all_formats_for
        |> Map.get(system_name)

      {:ok, struct(__MODULE__, formats)}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Return the predfined formats for a given `locale` and `number_system` or raises
  if either the `locale` or `number_system` is invalid.

  * `locale` is any locale configured in the system.  See `Cldr.known_locales/0`

  * `number_system` is either a `binary` or `atom`. See `Cldr.Number.Format.formats_for/2`
  for more information.
  """
  @spec formats_for!(LanguageTag.t, atom | String.t) :: Map.t | Exception.t
  def formats_for!(locale \\ Cldr.get_current_locale(), number_system \\ :default)
  def formats_for!(locale, number_system) do
    case formats_for(locale, number_system) do
      {:ok, formats} ->
        formats
      {:error, {exception, message}} ->
        raise exception, message
    end
  end

  @doc """
  Returns the format styles available for a `locale`.

  * `locale` is any locale configured in the system.  See `Cldr.known_locales/0`

  * `number_system` which defaults to `:default` and is either:

    * an `atom` in which case it is interpreted as a `number system type`
    in the given locale.  Typically this would be either `:default` or
    `:native`. See `Cldr.Number.Format.format_types_for/1` for the number
    system types available for a given `locale`.

    * a `binary` in which case it is used to look up the number system
    directly (for exmple `"latn"` which is common for western european
    languages). See `Cldr.Number.Format.formats_for/1` for the
    available formats for a `locale`.

  Format styles standardise the access to a format defined for a common
  use.  These types are `:standard`, `:currency`, `:accounting`, `:scientific`
  and :percent, :currency_short, :decimal_short, :decimal_long.

  These types can be used when formatting a number for output.  For example
  `Cldr.Number.to_string(123.456, format: :percent)`.

  ## Example

      iex> Cldr.Number.Format.format_styles_for(Cldr.Locale.new("en"))
      [:accounting, :currency, :currency_long, :currency_short,
      :decimal_long, :decimal_short, :percent, :scientific, :standard]

  """
  @spec format_styles_for(LanguageTag.t, atom | String.t) :: [atom, ...]
  def format_styles_for(locale \\ Cldr.get_current_locale(), number_system \\ :default)

  def format_styles_for(%LanguageTag{} = locale, number_system) do
    with {:ok, formats} <- formats_for(locale, number_system) do
      formats
      |> Map.to_list
      |> Enum.reject(fn {k, v} -> is_nil(v) || k == :__struct__  || k == :currency_spacing end)
      |> Enum.into(%{})
      |> Map.keys
    else
      {:error, _} = error -> error
    end
  end

  @doc """
  Returns the short formats available for a locale.

  * `locale` is any locale configured in the system.  See `Cldr.known_locales/0`

  * `number_system` which defaults to `:default` and is either:

    * an `atom` in which case it is interpreted as a `number system type`
    in the given locale.  Typically this would be either `:default` or
    `:native`. See `Cldr.Number.Format.format_types_for/1` for the number
    system types available for a given `locale`.

    * a `binary` in which case it is used to look up the number system
    directly (for exmple `"latn"` which is common for western european
    languages). See `Cldr.Number.Format.formats_for/1` for the
    available formats for a `locale`.

  ## Example

      iex> Cldr.Number.Format.short_format_styles_for(Cldr.Locale.new("he"))
      [:currency_short, :decimal_long, :decimal_short]

  """
  @isnt_really_a_short_format [:currency_long]
  @short_formats MapSet.new(@short_format_styles -- @isnt_really_a_short_format)

  @spec short_format_styles_for(LanguageTag.t, binary | atom) :: [atom, ...]
  def short_format_styles_for(locale \\ Cldr.get_current_locale(), number_system \\ :default)

  def short_format_styles_for(%LanguageTag{} = locale, number_system) do
    case formats = format_styles_for(locale, number_system) do
      {:error, _} = error ->
        error
      _ ->
        formats
        |> MapSet.new
        |> MapSet.intersection(@short_formats)
        |> MapSet.to_list
    end
  end

  @doc """
  Returns the decimal format styles that are supported by
  `Cldr.Number.Formatter.Decimal`.

  * `locale` is any locale configured in the system.  See `Cldr.known_locales/0`

  * `number_system` which defaults to `:default` and is either:

    * an `atom` in which case it is interpreted as a `number system type`
    in the given locale.  Typically this would be either `:default` or
    `:native`. See `Cldr.Number.Format.format_types_for/1` for the number
    system types available for a given `locale`.

    * a `binary` in which case it is used to look up the number system
    directly (for exmple `"latn"` which is common for western european
    languages). See `Cldr.Number.Format.formats_for/1` for the
    available formats for a `locale`.

  ## Example

      iex> Cldr.Number.Format.decimal_format_styles_for Cldr.Locale.new("en")
      [:accounting, :currency, :currency_long, :percent,
       :scientific, :standard]

  """
  @spec decimal_format_styles_for(LanguageTag.t, binary | atom) :: [atom]
  def decimal_format_styles_for(locale \\ Cldr.get_current_locale(), number_system \\ :default)

  def decimal_format_styles_for(%LanguageTag{} = locale, number_system) do
    case format_styles_for(locale, number_system) do
      [_ | _] = styles ->
        styles
        -- short_format_styles_for(locale, number_system)
        -- [:currency_long, :currency_spacing]
      {:error, _} = error ->
        error
    end
  end

  @doc """
  Returns the number system types available for a `locale`

  * `locale` is any locale configured in the system.  See `Cldr.known_locales/0`

  A number system type is an identifier that categorises number systems
  that comprise a site of digits or rules for transliterating or translating
  digits and a number system name for determining plural rules and format
  masks.

  If that all sounds a bit complicated then the default `number system type`
  called `:default` is probably what you want nearly all the time.

  ## Examples

      iex> Cldr.Number.Format.format_system_types_for Cldr.Locale.new("pl")
      {:ok, [:default, :native]}

      iex> Cldr.Number.Format.format_system_types_for Cldr.Locale.new("ru")
      {:ok, [:default, :native]}

      iex> Cldr.Number.Format.format_system_types_for Cldr.Locale.new("th")
      {:ok, [:default, :native]}

  """
  @spec format_system_types_for(LanguageTag.t) :: [atom, ...]
  def format_system_types_for(locale \\ Cldr.get_current_locale())

  def format_system_types_for(%LanguageTag{} = locale) do
    with {:ok, _} <- Cldr.validate_locale(locale) do
      {:ok, systems} = System.number_systems_for(locale)
      {:ok, Map.keys(systems)}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Returns the names of the number systems for the `locale`.

  * `locale` is any locale configured in the system.  See `Cldr.known_locales/0`

  ## Examples

      iex> Cldr.Number.Format.format_system_names_for(Cldr.Locale.new("th"))
      {:ok, [:latn, :thai]}

      iex> Cldr.Number.Format.format_system_names_for(Cldr.Locale.new("pl"))
      {:ok, [:latn]}

  """
  @spec format_system_names_for(LanguageTag.t) :: [String.t, ...]
  def format_system_names_for(locale \\ Cldr.get_current_locale())

  def format_system_names_for(%LanguageTag{} = locale) do
    Cldr.Number.System.number_system_names_for(locale)
  end

end
