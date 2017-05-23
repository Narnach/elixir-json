defmodule JSON.Parser.Bitstring.String do
  use Bitwise
  @doc """
  parses a valid JSON string, returns its elixir representation

  ## Examples

      iex> JSON.Parser.Bitstring.String.parse ""
      {:error, :unexpected_end_of_buffer}

      iex> JSON.Parser.Bitstring.String.parse "face0ff"
      {:error, {:unexpected_token, "face0ff"} }

      iex> JSON.Parser.Bitstring.String.parse "-hello"
      {:error, {:unexpected_token, "-hello"} }

      iex> JSON.Parser.Bitstring.String.parse "129245"
      {:error, {:unexpected_token, "129245"} }

      iex> JSON.Parser.Bitstring.String.parse "\\\"7.something\\\""
      {:ok, "7.something", "" }

      iex> JSON.Parser.Bitstring.String.parse "\\\"-88.22suffix\\\" foo bar"
      {:ok, "-88.22suffix", " foo bar" }

      iex> JSON.Parser.Bitstring.String.parse "\\\"star -> \\\\u272d <- star\\\""
      {:ok, "star -> ✭ <- star", "" }

      iex> JSON.Parser.Bitstring.String.parse "\\\"\\\\u00df ist wunderbar\\\""
      {:ok, "ß ist wunderbar", "" }

      iex> JSON.Parser.Bitstring.String.parse "\\\"Rafaëlla\\\" foo bar"
      {:ok, "Rafaëlla", " foo bar" }

      iex> JSON.Parser.Bitstring.String.parse "\\\"Éloise woot\\\" Éloise"
      {:ok, "Éloise woot", " Éloise" }
  """
  def parse(json) do
    case json do
      << ?" :: utf8 , rest :: binary >> -> parse_string_contents(rest, [])
      << >> -> { :error, :unexpected_end_of_buffer }
      _ -> { :error, { :unexpected_token, json } }
    end
  end

  defp parse_string_contents(json, acc) do
    case json do
      << >> -> { :error, :unexpected_end_of_buffer }
      << ?\\, ?f,  rest :: binary >> -> parse_string_contents(rest, [ ?\f | acc ])
      << ?\\, ?n,  rest :: binary >> -> parse_string_contents(rest, [ ?\n | acc ])
      << ?\\, ?r,  rest :: binary >> -> parse_string_contents(rest, [ ?\r | acc ])
      << ?\\, ?t,  rest :: binary >> -> parse_string_contents(rest, [ ?\t | acc ])
      << ?\\, ?",  rest :: binary >> -> parse_string_contents(rest, [ ?"  | acc ])
      << ?\\, ?\\, rest :: binary >> -> parse_string_contents(rest, [ ?\\ | acc ])
      << ?\\, ?/,  rest :: binary >> -> parse_string_contents(rest, [ ?/  | acc ])
      << ?\\, ?u , _ :: binary >> ->
        case JSON.Parser.Bitstring.Unicode.parse(json) do
          { :error, error_info } -> { :error, error_info }
          { :ok, decoded_unicode_codepoint, after_codepoint} ->
            case decoded_unicode_codepoint do
              << _ :: utf8 >> ->
                parse_string_contents(after_codepoint, [ decoded_unicode_codepoint | acc ])
              _ ->
                { :error, { :unexpected_token, json} }
            end
        end
      # found the closing ", lets reverse the acc and encode it as a string!
      << ?" :: utf8, rest :: binary >> ->
        case acc |> Enum.reverse |> List.to_string do
          encoded when is_binary(encoded) ->
            { :ok, encoded, rest }
          _ ->
            {:error, { :unexpected_token, json }}
        end
     << char :: utf8, rest :: binary >> -> parse_string_contents(rest, [ char | acc ])
    end
  end
end
