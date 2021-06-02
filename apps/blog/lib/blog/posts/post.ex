defmodule Blog.Posts.Post do
  @moduledoc """
  Encapsulates re-usable Ecto queries and schema/changeset definitions for blog posts
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  require Logger

  alias __MODULE__

  @draft_prefixes ["Draft", "WIP"]
  @average_words_read_per_minute 100

  schema "posts" do
    field :normalized_title, :string
    field :title, :string
    field :source_url, :string
    field :url, :string
    field :content, :string
    field :raw_content, :string
    field :description, :string
    field :reading_time_minutes, :integer

    field :created_at, :utc_datetime_usec
    field :updated_at, :utc_datetime_usec

    field :is_draft, :boolean, default: false

    field :tags, {:array, :string}
  end

  # Changeset functions ===========

  def changeset(%Post{} = post, attrs) do
    attrs = process_attrs(attrs)

    post
    |> cast(attrs, [
      :id,
      :title,
      :content,
      :created_at,
      :updated_at,
      :tags,
      :raw_content,
      :source_url
    ])
    |> validate_required([
      :id,
      :title,
      :content,
      :created_at,
      :updated_at,
      :tags,
      :raw_content,
      :source_url
    ])
    |> put_is_draft()
    |> put_normalized_title()
    |> put_url()
    |> put_estimated_reading_time()
    |> put_description()
    |> unique_constraint(:id)
    |> unique_constraint(:normalized_title)
  end

  defp process_attrs(%{"url" => url} = attrs),
    do: attrs |> Map.delete("url") |> Map.put("source_url", url)

  defp process_attrs(%{url: url} = attrs),
    do: attrs |> Map.delete(:url) |> Map.put(:source_url, url)

  defp process_attrs(attrs), do: attrs

  defp put_normalized_title(%Ecto.Changeset{changes: %{title: title}} = changeset) do
    normalized_title =
      ~r/[^((A-Za-z0-9)| )]/
      |> Regex.replace(title, "", capture: :all)
      |> trim_draft_prefix()
      |> String.trim(" ")
      |> String.replace(" ", "_")
      |> String.downcase()

    put_change(changeset, :normalized_title, normalized_title)
  end

  defp put_normalized_title(%Ecto.Changeset{} = changeset) do
    changeset
  end

  defp put_url(%Ecto.Changeset{changes: %{normalized_title: normalized_title}} = changeset) do
    put_change(changeset, :url, "/posts/#{normalized_title}")
  end

  defp put_url(%Ecto.Changeset{} = changeset) do
    changeset
  end

  defp trim_draft_prefix(title) do
    for prefix <- @draft_prefixes do
      if String.starts_with?(title, prefix) do
        throw({:done, String.replace_prefix(title, prefix, "")})
      end
    end

    title
  catch
    {:done, trimmed_title} ->
      trimmed_title
  end

  defp put_is_draft(%Ecto.Changeset{changes: %{title: title}} = changeset) do
    put_change(changeset, :is_draft, Enum.any?(@draft_prefixes, &String.starts_with?(title, &1)))
  end

  defp put_is_draft(%Ecto.Changeset{} = changeset) do
    changeset
  end

  defp put_estimated_reading_time(
         %Ecto.Changeset{changes: %{raw_content: raw_content}} = changeset
       ) do
    approximate_word_count =
      raw_content
      |> String.split(~r/\s/)
      |> Enum.count(fn string ->
        Regex.match?(~r/[a-zA-Z]+/, string)
      end)

    put_change(
      changeset,
      :reading_time_minutes,
      ceil(approximate_word_count / @average_words_read_per_minute)
    )
  end

  defp put_estimated_reading_time(%Ecto.Changeset{} = changeset) do
    changeset
  end

  defp put_description(%Ecto.Changeset{changes: %{content: content}} = changeset) do
    description =
      ~r/<p>.*?<h2>/s
      |> Regex.run(content)
      |> case do
        [first_match | _] ->
          String.trim_trailing(first_match, "\n<h2>")

        _ ->
          Logger.warn(
            "Could not generate a description for post #{
              changeset.changes.id || changeset.data.id
            }"
          )

          content
      end

    put_change(changeset, :description, description)
  end

  defp put_description(%Ecto.Changeset{} = changeset) do
    changeset
  end

  # Query functions ===========

  def where_id(query, id) do
    from p in query, where: p.id == ^id
  end

  def where_id_in(query, ids) do
    from p in query, where: p.id in ^ids
  end

  def where_normalized_title(query, normalized_title) do
    from p in query, where: p.normalized_title == ^normalized_title
  end

  def where_is_draft(query) do
    from p in query, where: p.is_draft == true
  end

  def where_not_is_draft(query) do
    from p in query, where: p.is_draft == false
  end
end
